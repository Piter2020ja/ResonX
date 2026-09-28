import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({
    required this.timestamp,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestampMs': timestamp.inMilliseconds,
      'text': text,
    };
  }

  factory LyricLine.fromMap(Map<String, dynamic> map) {
    return LyricLine(
      timestamp: Duration(milliseconds: map['timestampMs'] as int? ?? 0),
      text: map['text'] as String? ?? '',
    );
  }
}

class LyricsData {
  final String trackId;
  final String trackTitle;
  final String artistName;
  final List<LyricLine> lines;
  final bool isSynced;
  final String? plainLyrics;

  LyricsData({
    required this.trackId,
    required this.trackTitle,
    required this.artistName,
    required this.lines,
    required this.isSynced,
    this.plainLyrics,
  });

  bool get hasLyrics => lines.isNotEmpty || (plainLyrics != null && plainLyrics!.trim().isNotEmpty);
}

class LyricsService extends ChangeNotifier {
  static final LyricsService instance = LyricsService._internal();

  LyricsService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': 'ResonX-Client/2.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json',
        },
      ),
    );
  }

  late final Dio _dio;

  final Map<String, LyricsData> _cache = {};
  LyricsData? _currentLyrics;
  int _currentLineIndex = -1;
  bool _isLoading = false;
  String? _errorMessage;

  LyricsData? get currentLyrics => _currentLyrics;
  int get currentLineIndex => _currentLineIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // ELASTYCZNA METODA fetchLyrics (OBSŁUGUJE Track LUB title + artist)
  // ---------------------------------------------------------------------------

  Future<LyricsData?> fetchLyrics(
    dynamic trackOrTitle, [
    String? artist,
    int? durationSeconds,
  ]) async {
    if (trackOrTitle is Track) {
      return loadLyricsForTrack(trackOrTitle);
    }

    final titleStr = trackOrTitle?.toString() ?? '';
    final artistStr = artist ?? '';
    final dur = durationSeconds ?? 180;

    final dummyTrack = Track(
      id: '${titleStr}_$artistStr'.replaceAll(' ', '_'),
      title: titleStr,
      artist: artistStr,
      album: 'ResonX Master',
      durationSeconds: dur,
      coverUrl: '',
      audioUrl: '',
    );

    return loadLyricsForTrack(dummyTrack);
  }

  Future<LyricsData?> loadLyricsForTrack(Track track) async {
    if (_cache.containsKey(track.id)) {
      _currentLyrics = _cache[track.id];
      _currentLineIndex = -1;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return _currentLyrics;
    }

    _isLoading = true;
    _errorMessage = null;
    _currentLineIndex = -1;
    notifyListeners();

    try {
      final cleanTitle = _cleanTitle(track.title);
      final cleanArtist = _cleanArtist(track.artist);

      debugPrint('[ResonX Lyrics] Pobieranie tekstu: "$cleanTitle" autorstwa: "$cleanArtist"');

      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
          'duration': track.durationSeconds,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final syncedLyricsRaw = data['syncedLyrics']?.toString();
        final plainLyricsRaw = data['plainLyrics']?.toString();

        List<LyricLine> parsedLines = [];
        bool isSynced = false;

        if (syncedLyricsRaw != null && syncedLyricsRaw.trim().isNotEmpty) {
          parsedLines = _parseLrcFormat(syncedLyricsRaw);
          isSynced = parsedLines.isNotEmpty;
        }

        if (parsedLines.isEmpty && plainLyricsRaw != null && plainLyricsRaw.trim().isNotEmpty) {
          final rawLines = plainLyricsRaw.split('\n');
          for (final raw in rawLines) {
            final t = raw.trim();
            if (t.isNotEmpty) {
              parsedLines.add(LyricLine(timestamp: Duration.zero, text: t));
            }
          }
        }

        final result = LyricsData(
          trackId: track.id,
          trackTitle: track.title,
          artistName: track.artist,
          lines: parsedLines,
          isSynced: isSynced,
          plainLyrics: plainLyricsRaw,
        );

        _cache[track.id] = result;
        _currentLyrics = result;
        _isLoading = false;
        notifyListeners();
        return result;
      }
    } catch (e) {
      debugPrint('[ResonX Lyrics] Szukanie zapasowe w katalogu LRCLIB...');

      try {
        final fallbackQuery = '${track.artist} ${track.title}';
        final searchRes = await _dio.get(
          'https://lrclib.net/api/search',
          queryParameters: {'q': fallbackQuery},
        );

        if (searchRes.statusCode == 200 && searchRes.data is List && (searchRes.data as List).isNotEmpty) {
          final first = searchRes.data[0];
          final synced = first['syncedLyrics']?.toString();
          final plain = first['plainLyrics']?.toString();

          List<LyricLine> parsedLines = [];
          bool isSynced = false;

          if (synced != null && synced.trim().isNotEmpty) {
            parsedLines = _parseLrcFormat(synced);
            isSynced = parsedLines.isNotEmpty;
          }

          final result = LyricsData(
            trackId: track.id,
            trackTitle: track.title,
            artistName: track.artist,
            lines: parsedLines,
            isSynced: isSynced,
            plainLyrics: plain,
          );

          _cache[track.id] = result;
          _currentLyrics = result;
          _isLoading = false;
          notifyListeners();
          return result;
        }
      } catch (_) {}

      _errorMessage = 'Tekst utworu jest niedostępny.';
      _isLoading = false;
      notifyListeners();
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // POBIERANIE WERSU W CZASIE RZECZYWISTYM (BEZ PARAMETRU LUB Z PARAMETREM Duration)
  // ---------------------------------------------------------------------------

  String getLiveLine([Duration? position]) {
    if (position != null) {
      updatePlaybackPosition(position);
    }

    if (_currentLyrics == null || _currentLyrics!.lines.isEmpty) {
      return '';
    }
    if (_currentLineIndex >= 0 && _currentLineIndex < _currentLyrics!.lines.length) {
      return _currentLyrics!.lines[_currentLineIndex].text;
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // AKTUALIZACJA POZYCJI CZASOWEJ
  // ---------------------------------------------------------------------------

  void updatePlaybackPosition(Duration currentPosition) {
    if (_currentLyrics == null || !_currentLyrics!.isSynced || _currentLyrics!.lines.isEmpty) {
      return;
    }

    final lines = _currentLyrics!.lines;
    int targetIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      if (currentPosition >= lines[i].timestamp) {
        targetIndex = i;
      } else {
        break;
      }
    }

    if (targetIndex != _currentLineIndex) {
      _currentLineIndex = targetIndex;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // PARSER .LRC
  // ---------------------------------------------------------------------------

  List<LyricLine> _parseLrcFormat(String lrcContent) {
    final List<LyricLine> result = [];
    final pattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    final rawLines = lrcContent.split('\n');
    for (final line in rawLines) {
      final trimmed = line.trim();
      final match = pattern.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final rawFraction = match.group(3)!;
        final millis = rawFraction.length == 2
            ? int.parse(rawFraction) * 10
            : int.parse(rawFraction);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = match.group(4)?.trim() ?? '';

        if (text.isNotEmpty) {
          result.add(LyricLine(timestamp: timestamp, text: text));
        }
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'feat\..*|ft\..*|official.*|video.*|audio.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'prod\..*', caseSensitive: false), '')
        .trim();
  }

  String _cleanArtist(String artist) {
    if (artist.contains('/')) {
      return artist.split('/')[0].trim();
    }
    if (artist.contains(',')) {
      return artist.split(',')[0].trim();
    }
    return artist
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
        .trim();
  }

  void clearCurrentLyrics() {
    _currentLyrics = null;
    _currentLineIndex = -1;
    _errorMessage = null;
    notifyListeners();
  }

  void purgeCache() {
    _cache.clear();
    clearCurrentLyrics();
  }
}