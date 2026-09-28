import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'database_service.dart';

class LocalScannerService {
  static final LocalScannerService instance = LocalScannerService._();
  LocalScannerService._();

  Future<List<Track>> scanWindowsMusicDirectory() async {
    final List<Track> discoveredTracks = [];
    try {
      final musicDir = Directory('C:\\Users\\${Platform.environment['USERNAME']}\\Music');
      if (await musicDir.exists()) {
        await for (var entity in musicDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.endsWith('.mp3') || path.endsWith('.flac') || path.endsWith('.wav') || path.endsWith('.m4a') || path.endsWith('.ogg')) {
              final fileName = entity.uri.pathSegments.last;
              final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
              
              final track = Track(
                id: 'local_${path.hashCode}',
                title: nameWithoutExt.replaceAll('_', ' '),
                artist: 'Lokalny Plik Windows',
                album: 'ResonX Local Storage',
                durationSeconds: 210,
                coverUrl: '',
                audioUrl: entity.path,
                isOffline: true,
                localPath: entity.path,
                fileFormat: path.split('.').last.toUpperCase(),
                bitrate: path.endsWith('.flac') ? 1411 : 320,
                sampleRate: 44100,
              );

              discoveredTracks.add(track);
              await DatabaseService.instance.saveTrack(track);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Błąd skanowania dysku Windows: $e');
    }
    return discoveredTracks;
  }

  Future<void> exportPlaylistToJson(String playlistName, List<Track> tracks) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}\\${playlistName}_playlist.json');
      final data = tracks.map((t) => {'id': t.id, 'title': t.title, 'artist': t.artist, 'url': t.audioUrl}).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Błąd eksportu playlisty: $e');
    }
  }
}