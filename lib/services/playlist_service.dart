import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

/// Model playlisty użytkownika
class Playlist {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final List<Track> tracks;

  Playlist({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    List<Track>? tracks,
  }) : tracks = tracks ?? [];

  int get trackCount => tracks.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'tracks': tracks.map((t) => t.toMap()).toList(),
      };

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        tracks: (map['tracks'] as List<dynamic>?)
                ?.map((t) => Track.fromMap(t as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Wynik weryfikacji duplikatu
enum DuplicateStatus { none, exactMatch, fuzzyMatch }

class DuplicateCheckResult {
  final DuplicateStatus status;
  final Track? existingTrack;

  const DuplicateCheckResult(this.status, [this.existingTrack]);
}

/// Serwis zarządzania playlistami i rozwiązywania konfliktów duplikatów
class PlaylistService extends ChangeNotifier {
  static final PlaylistService instance = PlaylistService._();
  PlaylistService._();

  final List<Playlist> _playlists = [];
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Playlist? getPlaylistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Utworzenie nowej playlisty
  void createPlaylist(String title, [String description = '']) {
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
    );
    _playlists.add(newPlaylist);
    notifyListeners();
  }

  /// Usunięcie playlisty
  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  /// Inteligentne wykrywanie duplikatów (Exact ID lub Fuzzy Match po tytule i wykonawcy)
  DuplicateCheckResult checkForDuplicate(Playlist playlist, Track track) {
    // 1. Dokładne dopasowanie po ID utworu
    for (final existing in playlist.tracks) {
      if (existing.id == track.id) {
        return DuplicateCheckResult(DuplicateStatus.exactMatch, existing);
      }
    }

    // 2. Porównanie Fuzzy (oczyszczony tytuł i artysta)
    final cleanInputTitle = _cleanString(track.title);
    final cleanInputArtist = _cleanString(track.artist);

    for (final existing in playlist.tracks) {
      final cleanExistingTitle = _cleanString(existing.title);
      final cleanExistingArtist = _cleanString(existing.artist);

      if (cleanInputTitle == cleanExistingTitle &&
          cleanInputArtist == cleanExistingArtist) {
        return DuplicateCheckResult(DuplicateStatus.fuzzyMatch, existing);
      }
    }

    return const DuplicateCheckResult(DuplicateStatus.none);
  }

  /// Dodanie utworu do playlisty (z wymuszeniem dodania lub zamianą)
  void addTrackToPlaylist(String playlistId, Track track, {bool replaceExisting = false}) {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return;

    if (replaceExisting) {
      playlist.tracks.removeWhere((t) =>
          t.id == track.id ||
          (_cleanString(t.title) == _cleanString(track.title) &&
              _cleanString(t.artist) == _cleanString(track.artist)));
    }

    playlist.tracks.add(track);
    notifyListeners();
  }

  /// Usunięcie pojedynczego utworu z playlisty
  void removeTrackFromPlaylist(String playlistId, String trackId) {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return;

    playlist.tracks.removeWhere((t) => t.id == trackId);
    notifyListeners();
  }

  /// Eksport playlisty do formatu JSON
  String exportPlaylistToJson(String playlistId) {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return '';
    return jsonEncode(playlist.toMap());
  }

  /// Eksport playlisty do pliku .m3u
  String exportPlaylistToM3u(String playlistId) {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:${playlist.title}');

    for (final track in playlist.tracks) {
      buffer.writeln('#EXTINF:-1,${track.artist} - ${track.title}');
      buffer.writeln(track.id);
    }

    return buffer.toString();
  }

  String _cleanString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}