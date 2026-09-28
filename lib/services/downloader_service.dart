import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'api_service.dart';
import 'database_service.dart';

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class DownloadTask {
  final Track track;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;

  DownloadTask({
    required this.track,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
  });

  DownloadTask copyWith({
    Track? track,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadTask(
      track: track ?? this.track,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class DownloaderService extends ChangeNotifier {
  static final DownloaderService instance = DownloaderService._internal();

  DownloaderService._internal() {
    _initDirectory();
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  final Map<String, DownloadTask> _activeDownloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  Directory? _storageDir;

  Map<String, DownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);

  Future<void> _initDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _storageDir = Directory('${appDir.path}/ResonXOfflineStorage/AudioTracks');
      if (!await _storageDir!.exists()) {
        await _storageDir!.create(recursive: true);
      }
      debugPrint('[ResonX Downloader Engine] Magazyn gotowy: ${_storageDir!.path}');
    } catch (e) {
      debugPrint('[ResonX Downloader Error] Błąd inicjalizacji katalogu pobierania: $e');
    }
  }

  Future<String> _getDestinationPath(Track track) async {
    if (_storageDir == null) {
      await _initDirectory();
    }
    final sanitizedId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${_storageDir!.path}/$sanitizedId.mp3';
  }

  bool isDownloadedLocally(String trackId) {
    if (_storageDir == null) return false;
    final sanitizedId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${_storageDir!.path}/$sanitizedId.mp3');
    return file.existsSync() && file.lengthSync() > 1024;
  }

  String? getLocalFilePath(String trackId) {
    if (_storageDir == null) return null;
    final sanitizedId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${_storageDir!.path}/$sanitizedId.mp3');
    return file.existsSync() ? file.path : null;
  }

  DownloadTask? getTask(String trackId) => _activeDownloads[trackId];

  bool isDownloading(String trackId) {
    final task = _activeDownloads[trackId];
    return task != null && task.status == DownloadStatus.downloading;
  }

  double getDownloadProgress(String trackId) {
    final task = _activeDownloads[trackId];
    return task != null ? task.progress : 0.0;
  }

  Future<void> downloadTrack(Track track) async {
    if (isDownloadedLocally(track.id)) {
      debugPrint('[ResonX Downloader] Utwór już pobrany na dysku: ${track.title}');
      final path = await _getDestinationPath(track);
      await DatabaseService.instance.registerOfflineTrack(track, path);
      return;
    }

    if (isDownloading(track.id)) {
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[track.id] = cancelToken;

    _activeDownloads[track.id] = DownloadTask(
      track: track,
      progress: 0.0,
      status: DownloadStatus.downloading,
    );
    notifyListeners();

    try {
      final streamResult = await ApiService.instance.resolveDirectAudioStream(track);
      final downloadUrl = streamResult.directUrl;
      final targetPath = await _getDestinationPath(track);
      final tempPath = '$targetPath.tmp';

      debugPrint('[ResonX Downloader] Rozpoczynanie pobierania: ${track.title}');

      await _dio.download(
        downloadUrl,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total).clamp(0.0, 1.0);
            _activeDownloads[track.id] = DownloadTask(
              track: track,
              progress: progress,
              status: DownloadStatus.downloading,
            );
            notifyListeners();
          }
        },
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(targetPath);
      }

      await DatabaseService.instance.registerOfflineTrack(track, targetPath);

      _activeDownloads[track.id] = DownloadTask(
        track: track,
        progress: 1.0,
        status: DownloadStatus.completed,
      );
      _cancelTokens.remove(track.id);
      notifyListeners();
      debugPrint('[ResonX Downloader] Zakończono pobieranie utworu: ${track.title}');
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        debugPrint('[ResonX Downloader] Pobieranie anulowane: ${track.title}');
      } else {
        debugPrint('[ResonX Downloader Error] Błąd pobierania utworu ${track.title}: $e');
      }
      _activeDownloads[track.id] = DownloadTask(
        track: track,
        progress: 0.0,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      _cancelTokens.remove(track.id);
      notifyListeners();
    }
  }

  void cancelDownload(String trackId) {
    if (_cancelTokens.containsKey(trackId)) {
      _cancelTokens[trackId]?.cancel('Anulowano przez użytkownika');
      _cancelTokens.remove(trackId);
      _activeDownloads.remove(trackId);
      notifyListeners();
    }
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    try {
      final localPath = getLocalFilePath(trackId);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _activeDownloads.remove(trackId);
      _cancelTokens.remove(trackId);
      await DatabaseService.instance.unregisterOfflineTrack(trackId);
      notifyListeners();
      debugPrint('[ResonX Downloader] Usunięto utwór offline: $trackId');
    } catch (e) {
      debugPrint('[ResonX Downloader Error] Błąd usuwania utworu offline: $e');
    }
  }
}