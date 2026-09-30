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
  final int receivedBytes;
  final int totalBytes;

  DownloadTask({
    required this.track,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  DownloadTask copyWith({
    Track? track,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
    int? receivedBytes,
    int? totalBytes,
  }) {
    return DownloadTask(
      track: track ?? this.track,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
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
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  final Map<String, DownloadTask> _activeDownloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  Directory? _storageDir;
  bool _isBatchDownloading = false;

  Map<String, DownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);
  bool get isBatchDownloading => _isBatchDownloading;

  Future<void> _initDirectory() async {
    try {
      Directory baseDir;
      if (Platform.isIOS) {
        baseDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isAndroid) {
        baseDir = await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getApplicationSupportDirectory();
      }

      _storageDir = Directory('${baseDir.path}/ResonXOfflineStorage/AudioTracks');
      if (!await _storageDir!.exists()) {
        await _storageDir!.create(recursive: true);
      }

      await cleanTemporaryArtifacts();
      debugPrint('[ResonX Downloader Engine] Magazyn gotowy: ${_storageDir!.path}');
    } catch (e) {
      debugPrint('[ResonX Downloader Error] Błąd inicjalizacji katalogu pobierania: $e');
    }
  }

  String _sanitizeTrackId(String trackId) {
    return trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<String> _getDestinationPath(Track track, {String extension = 'mp3'}) async {
    if (_storageDir == null) {
      await _initDirectory();
    }
    final sanitizedId = _sanitizeTrackId(track.id);
    return '${_storageDir!.path}/$sanitizedId.$extension';
  }

  bool isDownloadedLocally(String trackId) {
    if (_storageDir == null) return false;
    final sanitizedId = _sanitizeTrackId(trackId);
    
    // Sprawdzanie MP3 oraz formatów AAC/M4A/FLAC
    final extensions = ['mp3', 'm4a', 'opus', 'flac'];
    for (final ext in extensions) {
      final file = File('${_storageDir!.path}/$sanitizedId.$ext');
      if (file.existsSync() && file.lengthSync() > 1024) {
        return true;
      }
    }
    return false;
  }

  String? getLocalFilePath(String trackId) {
    if (_storageDir == null) return null;
    final sanitizedId = _sanitizeTrackId(trackId);
    
    final extensions = ['mp3', 'm4a', 'opus', 'flac'];
    for (final ext in extensions) {
      final file = File('${_storageDir!.path}/$sanitizedId.$ext');
      if (file.existsSync() && file.lengthSync() > 1024) {
        return file.path;
      }
    }
    return null;
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

  // Oblicza wagę wszystkich pobranych utworów offline w megabajtach (MB)
  Future<double> calculateOfflineStorageSizeMb() async {
    try {
      if (_storageDir == null) await _initDirectory();
      if (_storageDir != null && await _storageDir!.exists()) {
        int totalBytes = 0;
        final files = _storageDir!.listSync();
        for (var entity in files) {
          if (entity is File) {
            final p = entity.path.toLowerCase();
            if (p.endsWith('.mp3') || p.endsWith('.m4a') || p.endsWith('.opus') || p.endsWith('.flac')) {
              totalBytes += entity.lengthSync();
            }
          }
        }
        return totalBytes / (1024 * 1024);
      }
    } catch (e) {
      debugPrint('[ResonX Downloader] Błąd obliczania rozmiaru plików: $e');
    }
    return 0.0;
  }

  // Czyści pozostałości po przerwanych lub uszkodzonych pobraniach (.tmp)
  Future<void> cleanTemporaryArtifacts() async {
    try {
      if (_storageDir != null && await _storageDir!.exists()) {
        final files = _storageDir!.listSync();
        for (var entity in files) {
          if (entity is File && entity.path.endsWith('.tmp')) {
            await entity.delete();
            debugPrint('[ResonX Downloader] Usunięto uszkodzony plik tymczasowy: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('[ResonX Downloader] Błąd czyszczenia plików .tmp: $e');
    }
  }

  // Pobieranie całej listy utworów po kolei
  Future<void> downloadBatch(List<Track> tracks) async {
    _isBatchDownloading = true;
    notifyListeners();

    for (final track in tracks) {
      if (!isDownloadedLocally(track.id)) {
        await downloadTrack(track);
      }
    }

    _isBatchDownloading = false;
    notifyListeners();
  }

  Future<void> downloadTrack(Track track) async {
    if (isDownloadedLocally(track.id)) {
      debugPrint('[ResonX Downloader] Utwór już pobrany na dysku: ${track.title}');
      final existingPath = getLocalFilePath(track.id);
      if (existingPath != null) {
        await DatabaseService.instance.registerOfflineTrack(track, existingPath);
      }
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
      
      // Dynamiczne określenie rozszerzenia pliku ze strumienia
      String fileExt = 'mp3';
      final lowerUrl = downloadUrl.toLowerCase();
      if (lowerUrl.contains('.m4a')) {
        fileExt = 'm4a';
      } else if (lowerUrl.contains('.opus')) {
        fileExt = 'opus';
      } else if (lowerUrl.contains('.flac')) {
        fileExt = 'flac';
      }

      final targetPath = await _getDestinationPath(track, extension: fileExt);
      final tempPath = '$targetPath.tmp';

      debugPrint('[ResonX Downloader] Rozpoczynanie pobierania: ${track.title}');

      // Dynamiczny dobór nagłówków zapobiegający blokadom 403 Forbidden
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Accept': '*/*',
      };

      if (downloadUrl.contains('soundcloud.com') || downloadUrl.contains('sndcdn.com')) {
        requestHeaders['Referer'] = 'https://soundcloud.com/';
      } else if (downloadUrl.contains('googlevideo.com') || downloadUrl.contains('youtube')) {
        requestHeaders['Referer'] = 'https://music.youtube.com/';
      }

      await _dio.download(
        downloadUrl,
        tempPath,
        cancelToken: cancelToken,
        options: Options(headers: requestHeaders),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            _activeDownloads[track.id] = DownloadTask(
              track: track,
              progress: progress,
              status: DownloadStatus.downloading,
              receivedBytes: received,
              totalBytes: total,
            );
            notifyListeners();
          }
        },
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final destFile = File(targetPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
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
      bool isCancelled = false;
      if (e is DioException && CancelToken.isCancel(e)) {
        isCancelled = true;
      }

      if (isCancelled) {
        debugPrint('[ResonX Downloader] Pobieranie anulowane: ${track.title}');
      } else {
        debugPrint('[ResonX Downloader Error] Błąd pobierania utworu ${track.title}: $e');
      }

      // Sprzątanie pliku .tmp w razie błędu
      try {
        final targetPath = await _getDestinationPath(track);
        final tempFile = File('$targetPath.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

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