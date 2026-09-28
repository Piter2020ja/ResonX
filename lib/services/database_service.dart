import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class UserPlaylist {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final DateTime createdAt;
  final List<Track> tracks;

  UserPlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.createdAt,
    required this.tracks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'createdAt': createdAt.toIso8601String(),
      'tracks': tracks.map((t) => t.toMap()).toList(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory UserPlaylist.fromMap(Map<String, dynamic> map) {
    final rawTracks = map['tracks'] as List? ?? [];
    return UserPlaylist(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Nowa playlista',
      description: map['description'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      tracks: rawTracks
          .map((t) => Track.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist.fromMap(json);

  UserPlaylist copyWith({
    String? id,
    String? title,
    String? description,
    String? coverUrl,
    DateTime? createdAt,
    List<Track>? tracks,
  }) {
    return UserPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      tracks: tracks ?? this.tracks,
    );
  }
}

class MockRawDbExecutor {
  Future<List<Map<String, dynamic>>> query(String table, {dynamic where, List<dynamic>? whereArgs}) async => [];
  Future<int> insert(String table, Map<String, dynamic> values, {dynamic conflictAlgorithm}) async => 1;
  Future<int> update(String table, Map<String, dynamic> values, {dynamic where, List<dynamic>? whereArgs}) async => 1;
  Future<int> delete(String table, {dynamic where, List<dynamic>? whereArgs}) async => 1;
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {}
}

class DatabaseService extends ChangeNotifier {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal() {
    init();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Obiekt bazy wymagany przez auth_cloud_service.dart do logowania i synchronizacji konta
  final MockRawDbExecutor _mockDb = MockRawDbExecutor();
  dynamic get database => _mockDb;

  final List<Track> _savedTracks = [];
  final List<Track> _favoriteTracks = [];
  final List<UserPlaylist> _playlists = [];
  final List<Track> _offlineTracks = [];

  List<Track> get savedTracks => List.unmodifiable(_savedTracks);
  List<Track> get favoriteTracks => List.unmodifiable(_favoriteTracks);
  List<UserPlaylist> get playlists => List.unmodifiable(_playlists);
  List<Track> get offlineTracks => List.unmodifiable(_offlineTracks);

  int get favoritesCount => _favoriteTracks.length;
  int get playlistsCount => _playlists.length;
  int get offlineCount => _offlineTracks.length;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _loadFavorites();
      await _loadPlaylists();
      await _loadOfflineTracks();
      await _loadSavedTracks();
      _isInitialized = true;
      notifyListeners();
      debugPrint('[ResonX Database] Baza zainicjalizowana. Ulubione: ${_favoriteTracks.length}, Playlisty: ${_playlists.length}');
    } catch (e, stack) {
      debugPrint('[ResonX Database Error] $e\n$stack');
    }
  }

  Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final resonxDir = Directory('${dir.path}/ResonXStorage');
    if (!resonxDir.existsSync()) {
      resonxDir.createSync(recursive: true);
    }
    return File('${resonxDir.path}/$filename');
  }

  // ---------------------------------------------------------------------------
  // METODA saveTrack - WYMAGANA PRZEZ local_scanner_service I metadata_tag_editor
  // ---------------------------------------------------------------------------

  Future<void> saveTrack(Track track) async {
    final idx = _savedTracks.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      _savedTracks[idx] = track;
    } else {
      _savedTracks.add(track);
    }

    if (track.isFavorite) {
      final favIdx = _favoriteTracks.indexWhere((t) => t.id == track.id);
      if (favIdx >= 0) {
        _favoriteTracks[favIdx] = track;
      } else {
        _favoriteTracks.insert(0, track);
      }
      await _saveFavorites();
    }

    if (track.isOffline && track.localPath != null) {
      final offIdx = _offlineTracks.indexWhere((t) => t.id == track.id);
      if (offIdx >= 0) {
        _offlineTracks[offIdx] = track;
      } else {
        _offlineTracks.insert(0, track);
      }
      await _saveOfflineTracks();
    }

    try {
      final file = await _getFile('saved_tracks.json');
      await file.writeAsString(jsonEncode(_savedTracks.map((t) => t.toMap()).toList()));
    } catch (_) {}

    notifyListeners();
  }

  Future<void> _loadSavedTracks() async {
    try {
      final file = await _getFile('saved_tracks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List decoded = jsonDecode(content);
          _savedTracks.clear();
          for (final item in decoded) {
            _savedTracks.add(Track.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // ULUBIONE UTWORY (PEŁNE MODELE TRACK)
  // ---------------------------------------------------------------------------

  Future<void> _loadFavorites() async {
    try {
      final file = await _getFile('favorites.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List decoded = jsonDecode(content);
          _favoriteTracks.clear();
          for (final item in decoded) {
            _favoriteTracks.add(Track.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final file = await _getFile('favorites.json');
      final listData = _favoriteTracks.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(listData));
    } catch (_) {}
  }

  bool isFavorite(String trackId) {
    return _favoriteTracks.any((t) => t.id == trackId);
  }

  Future<void> toggleFavorite(Track track) async {
    final index = _favoriteTracks.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _favoriteTracks.removeAt(index);
    } else {
      _favoriteTracks.insert(0, track.copyWith(isFavorite: true));
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> addFavorite(Track track) async {
    if (!isFavorite(track.id)) {
      _favoriteTracks.insert(0, track.copyWith(isFavorite: true));
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> removeFavorite(String trackId) async {
    final index = _favoriteTracks.indexWhere((t) => t.id == trackId);
    if (index >= 0) {
      _favoriteTracks.removeAt(index);
      await _saveFavorites();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // PLAYLISTY UŻYTKOWNIKA
  // ---------------------------------------------------------------------------

  Future<void> _loadPlaylists() async {
    try {
      final file = await _getFile('playlists.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List decoded = jsonDecode(content);
          _playlists.clear();
          for (final item in decoded) {
            _playlists.add(UserPlaylist.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _savePlaylists() async {
    try {
      final file = await _getFile('playlists.json');
      final listData = _playlists.map((p) => p.toMap()).toList();
      await file.writeAsString(jsonEncode(listData));
    } catch (_) {}
  }

  Future<UserPlaylist> createPlaylist(String title, {String description = ''}) async {
    final newPlaylist = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Nowa playlista' : title.trim(),
      description: description.trim(),
      coverUrl: '',
      createdAt: DateTime.now(),
      tracks: [],
    );
    _playlists.insert(0, newPlaylist);
    await _savePlaylists();
    notifyListeners();
    return newPlaylist;
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final current = _playlists[index];
      if (!current.tracks.any((t) => t.id == track.id)) {
        final updatedTracks = List<Track>.from(current.tracks)..add(track);
        final updatedCover = current.coverUrl.isEmpty ? track.coverUrl : current.coverUrl;
        _playlists[index] = current.copyWith(
          tracks: updatedTracks,
          coverUrl: updatedCover,
        );
        await _savePlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final current = _playlists[index];
      final updatedTracks = List<Track>.from(current.tracks)
        ..removeWhere((t) => t.id == trackId);
      _playlists[index] = current.copyWith(tracks: updatedTracks);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePlaylists();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // POBIERANIE OFFLINE (BEZ SIECI)
  // ---------------------------------------------------------------------------

  Future<void> _loadOfflineTracks() async {
    try {
      final file = await _getFile('offline_tracks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List decoded = jsonDecode(content);
          _offlineTracks.clear();
          for (final item in decoded) {
            final t = Track.fromMap(Map<String, dynamic>.from(item as Map));
            if (t.localPath != null && File(t.localPath!).existsSync()) {
              _offlineTracks.add(t);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveOfflineTracks() async {
    try {
      final file = await _getFile('offline_tracks.json');
      final listData = _offlineTracks.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(listData));
    } catch (_) {}
  }

  Future<void> registerOfflineTrack(Track track, String localFilePath) async {
    _offlineTracks.removeWhere((t) => t.id == track.id);
    final offlineTrack = track.copyWith(
      localPath: localFilePath,
      isOffline: true,
    );
    _offlineTracks.insert(0, offlineTrack);
    await _saveOfflineTracks();
    notifyListeners();
  }

  Future<void> unregisterOfflineTrack(String trackId) async {
    _offlineTracks.removeWhere((t) => t.id == trackId);
    await _saveOfflineTracks();
    notifyListeners();
  }
}