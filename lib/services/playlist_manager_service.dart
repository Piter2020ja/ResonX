import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class PlaylistManagerService extends ChangeNotifier {
  static final PlaylistManagerService instance = PlaylistManagerService._();
  PlaylistManagerService._();

  final Map<String, List<Track>> _playlists = {};
  Map<String, List<Track>> get playlists => Map.unmodifiable(_playlists);

  void createPlaylist(String name) {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = [];
      notifyListeners();
      debugPrint('Utworzono nową playlistę: $name');
    }
  }

  void addTrackToPlaylist(String playlistName, Track track) {
    if (_playlists.containsKey(playlistName)) {
      _playlists[playlistName]!.add(track);
      notifyListeners();
      debugPrint('Dodano utwór ${track.title} do playlisty $playlistName');
    }
  }

  Future<void> exportPlaylistM3u(String playlistName) async {
    final tracks = _playlists[playlistName];
    if (tracks == null || tracks.isEmpty) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}\\$playlistName.m3u');
      
      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      for (var t in tracks) {
        buffer.writeln('#EXTINF:${t.durationSeconds},${t.artist} - ${t.title}');
        buffer.writeln(t.audioUrl);
      }

      await file.writeAsString(buffer.toString());
      debugPrint('Wyeksportowano playlistę M3U do: ${file.path}');
    } catch (e) {
      debugPrint('Błąd eksportu M3U: $e');
    }
  }

  Future<void> exportPlaylistJson(String playlistName) async {
    final tracks = _playlists[playlistName];
    if (tracks == null || tracks.isEmpty) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}\\$playlistName.json');
      
      final data = tracks.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'durationSeconds': t.durationSeconds,
        'audioUrl': t.audioUrl,
      }).toList();

      await file.writeAsString(jsonEncode(data));
      debugPrint('Wyeksportowano playlistę JSON do: ${file.path}');
    } catch (e) {
      debugPrint('Błąd eksportu JSON: $e');
    }
  }
}