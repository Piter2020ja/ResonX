import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

enum MusicPlatformSource {
  soundCloud,
  fallbackCdn,
}

class ResonXLrcLine {
  final Duration timestamp;
  final String text;

  ResonXLrcLine({required this.timestamp, required this.text});
}

class DirectAudioStreamResult {
  final String directUrl;
  final String audioFormat;
  final int bitrateKbps;
  final int contentLengthBytes;
  final MusicPlatformSource platform;
  final bool isDirectDownloadable;
  final Map<String, String> requiredHttpHeaders;
  final DateTime streamExpiryTime;

  DirectAudioStreamResult({
    required this.directUrl,
    required this.audioFormat,
    required this.bitrateKbps,
    required this.contentLengthBytes,
    required this.platform,
    required this.isDirectDownloadable,
    required this.requiredHttpHeaders,
    required this.streamExpiryTime,
  });
}

class ApiService {
  static final ApiService instance = ApiService._internal();

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-site',
        },
      ),
    );
  }

  late final Dio _dio;

  String? _dynamicClientId;
  DateTime? _clientIdExpiry;

  final Map<String, List<Track>> _searchQueryCache = {};
  final Map<String, DirectAudioStreamResult> _directStreamCache = {};
  final Map<String, List<ResonXLrcLine>> _lyricsCache = {};
  final Map<String, List<Track>> _artistDiscographyCache = {};

  int _totalNetworkRequests = 0;
  int _cacheHits = 0;

  Map<String, List<Track>> get searchQueryCache => _searchQueryCache;
  Map<String, DirectAudioStreamResult> get directStreamCache => _directStreamCache;
  Map<String, List<ResonXLrcLine>> get lyricsCache => _lyricsCache;
  Map<String, List<Track>> get artistDiscographyCache => _artistDiscographyCache;

  final Map<String, String> _streamHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
    'Referer': 'https://soundcloud.com/',
  };

  // ---------------------------------------------------------------------------
  // PRAWDZIWY DYNAMICZNY SCRAPER TOKENA CLIENT_ID Z SOUNDCLOUD CDN
  // ---------------------------------------------------------------------------

  Future<String> _getClientId() async {
    if (_dynamicClientId != null &&
        _clientIdExpiry != null &&
        DateTime.now().isBefore(_clientIdExpiry!)) {
      return _dynamicClientId!;
    }

    try {
      debugPrint('[ResonX Token Engine] Pobieranie świeżego tokena z serwerów SoundCloud...');
      final homeResponse = await _dio.get(
        'https://soundcloud.com',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      final html = homeResponse.data.toString();

      // Wyciąganie wszystkich skryptów z CDN SoundCloud (a-v2.sndcdn.com)
      final scriptRegex = RegExp(r'https?://[a-zA-Z0-9.-]*sndcdn\.com/assets/[a-zA-Z0-9._-]+\.js');
      final scriptMatches = scriptRegex.allMatches(html).map((m) => m.group(0)!).toSet().toList();

      for (final jsUrl in scriptMatches.reversed) {
        try {
          final jsResponse = await _dio.get(
            jsUrl,
            options: Options(responseType: ResponseType.plain),
          );
          final jsCode = jsResponse.data.toString();

          // Wzorzec dopasowujący client_id z plików JS SoundCloud
          final idPatterns = [
            RegExp(r'client_id[:=]["\x27]([a-zA-Z0-9]{32})["\x27]'),
            RegExp(r'client_id:"([a-zA-Z0-9]{32})"'),
            RegExp(r'client_id=([a-zA-Z0-9]{32})'),
            RegExp(r'["\x27]?client_id["\x27]?\s*:\s*["\x27]([a-zA-Z0-9]{32})["\x27]'),
          ];

          for (final pattern in idPatterns) {
            final match = pattern.firstMatch(jsCode);
            if (match != null) {
              final foundId = match.group(1);
              if (foundId != null && foundId.length == 32) {
                _dynamicClientId = foundId;
                _clientIdExpiry = DateTime.now().add(const Duration(hours: 4));
                debugPrint('[ResonX Token Engine] Sukces! Pobrany aktywny client_id: $_dynamicClientId');
                return _dynamicClientId!;
              }
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('[ResonX Token Engine] Błąd podczas dynamicznego pobierania tokena: $e');
    }

    // Bezpieczny fallback na wypadek braku połączenia przy pierwszym uruchomieniu
    _dynamicClientId ??= 'iZIs9mchVcX5lhVR1HNuuDZUT8t6Pabw';
    return _dynamicClientId!;
  }

  // ---------------------------------------------------------------------------
  // SYSTEM TRAFNOŚCI I ANTY-REMIX (ORYGINAŁY NA SAMĄ GÓRĘ)
  // ---------------------------------------------------------------------------

  int _calculateTrackRelevanceScore(Track track, String originalQuery) {
    int score = 0;
    final query = originalQuery.toLowerCase().trim();
    final queryWords = query.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final combined = '$artist - $title';

    if (track.isOfficial) {
      score += 250;
    }

    int matchedWords = 0;
    for (final word in queryWords) {
      if (title.contains(word) || artist.contains(word)) {
        matchedWords++;
      }
    }
    if (queryWords.isNotEmpty && matchedWords == queryWords.length) {
      score += 150;
    }

    if (artist == query) {
      score += 120;
    } else if (artist.contains(query) || query.contains(artist)) {
      score += 60;
    }

    if (title == query) {
      score += 130;
    } else if (title.startsWith(query)) {
      score += 50;
    }

    const junkWords = [
      'remix',
      'drill remix',
      'drill version',
      'flip',
      'edit',
      'slowed',
      'reverb',
      'slowed reverb',
      'sped up',
      'speed up',
      'nightcore',
      'bass boosted',
      'bassboost',
      'instrumental',
      'karaoke',
      'cover',
      'tribute',
      'type beat',
      'acapella',
      'bootleg',
      'club mix'
    ];

    for (final junk in junkWords) {
      if ((title.contains(junk) || combined.contains(junk)) && !query.contains(junk)) {
        score -= 200;
      }
    }

    if (track.durationSeconds >= 90 && track.durationSeconds <= 330) {
      score += 40;
    } else if (track.durationSeconds < 60) {
      score -= 100;
    } else if (track.durationSeconds > 600) {
      score -= 150;
    }

    return score;
  }

  // ---------------------------------------------------------------------------
  // GŁÓWNA METODA WYSZUKIWANIA (CZYSTY SOUNDCLOUD)
  // ---------------------------------------------------------------------------

  Future<List<Track>> searchTracks(
    String query, {
    int targetResultsCount = 40,
    bool includeYouTube = false,
    bool includeSoundCloud = true,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    if (_searchQueryCache.containsKey(cleanQuery)) {
      _cacheHits++;
      return _searchQueryCache[cleanQuery]!;
    }

    _totalNetworkRequests++;
    debugPrint('[ResonX Search Engine] Pobieranie wyników dla: "$cleanQuery"');

    final List<Track> combinedTracks = [];

    try {
      String clientId = await _getClientId();
      Response? response;
      try {
        response = await _dio.get(
          'https://api-v2.soundcloud.com/search/tracks',
          queryParameters: {
            'q': cleanQuery,
            'client_id': clientId,
            'limit': targetResultsCount,
          },
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': 'https://soundcloud.com/',
            },
          ),
        ).timeout(const Duration(seconds: 10));
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          debugPrint('[ResonX Search Engine] Wykryto 401! Unieważniam stary token i pobieram świeży z CDN...');
          _dynamicClientId = null;
          _clientIdExpiry = null;
          clientId = await _getClientId();

          response = await _dio.get(
            'https://api-v2.soundcloud.com/search/tracks',
            queryParameters: {
              'q': cleanQuery,
              'client_id': clientId,
              'limit': targetResultsCount,
            },
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Referer': 'https://soundcloud.com/',
              },
            ),
          ).timeout(const Duration(seconds: 10));
        } else {
          rethrow;
        }
      }

      if (response != null && response.statusCode == 200 && response.data != null) {
        final collection = response.data['collection'] as List?;
        if (collection != null) {
          for (final item in collection) {
            final id = 'sc_${item['id']}';
            final title = item['title']?.toString() ?? 'Nieznany utwór';
            final artist = item['user']?['username']?.toString() ?? 'Wykonawca';

            int durationSeconds = 180;
            if (item['duration'] is int) {
              durationSeconds = (item['duration'] as int) ~/ 1000;
            }

            String cover = item['artwork_url']?.toString() ?? '';
            if (cover.isNotEmpty) {
              cover = cover.replaceAll('-large', '-t500x500');
            } else {
              cover = item['user']?['avatar_url']?.toString() ?? '';
            }

            String streamProgressiveUrl = '';
            if (item['media'] != null && item['media']['transcodings'] is List) {
              final transcodings = item['media']['transcodings'] as List;
              for (final tc in transcodings) {
                if (tc['format']?['protocol'] == 'progressive') {
                  streamProgressiveUrl = tc['url'] ?? '';
                  break;
                }
              }
              if (streamProgressiveUrl.isEmpty && transcodings.isNotEmpty) {
                streamProgressiveUrl = transcodings.first['url'] ?? '';
              }
            }

            combinedTracks.add(
              Track(
                id: id,
                title: title,
                artist: artist,
                album: 'SoundCloud Original',
                durationSeconds: durationSeconds,
                coverUrl: cover,
                audioUrl: streamProgressiveUrl,
                isOfficial: item['user']?['verified'] == true,
                bitrate: 256,
                fileFormat: 'MP3',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ResonX Search Engine] Błąd pobierania z SoundCloud: $e');
    }

    if (combinedTracks.isNotEmpty) {
      final Map<String, Track> uniqueMap = {};
      for (final t in combinedTracks) {
        final key = '${t.artist.toLowerCase()}_${t.title.toLowerCase()}';
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = t;
        }
      }

      final List<Track> sortedList = uniqueMap.values.toList();
      sortedList.sort((a, b) {
        final scoreA = _calculateTrackRelevanceScore(a, cleanQuery);
        final scoreB = _calculateTrackRelevanceScore(b, cleanQuery);
        return scoreB.compareTo(scoreA);
      });

      _searchQueryCache[cleanQuery] = sortedList;
      return sortedList;
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // POBIERANIE STRUMIENIA BAJTÓW
  // ---------------------------------------------------------------------------

  Future<Stream<List<int>>?> getTrackAudioByteStream(Track track) async {
    try {
      final streamResult = await resolveDirectAudioStream(track);
      if (streamResult.directUrl.isNotEmpty) {
        final res = await _dio.get<ResponseBody>(
          streamResult.directUrl,
          options: Options(responseType: ResponseType.stream),
        );
        return res.data?.stream;
      }
    } catch (e) {
      debugPrint('[ResonX Audio Engine Error] Błąd strumienia bajtów: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ROZWIĄZYWANIE STRUMIENIA AUDIO
  // ---------------------------------------------------------------------------

  Future<DirectAudioStreamResult> resolveDirectAudioStream(Track track) async {
    if (_directStreamCache.containsKey(track.id)) {
      final cached = _directStreamCache[track.id]!;
      if (DateTime.now().isBefore(cached.streamExpiryTime)) {
        _cacheHits++;
        return cached;
      }
    }

    _totalNetworkRequests++;

    if (track.audioUrl.isNotEmpty) {
      final clientId = await _getClientId();
      try {
        final res = await _dio.get(
          track.audioUrl,
          queryParameters: {'client_id': clientId},
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': 'https://soundcloud.com/',
            },
          ),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 && res.data != null && res.data['url'] != null) {
          final directUrl = res.data['url'] as String;
          final result = DirectAudioStreamResult(
            directUrl: directUrl,
            audioFormat: 'mp3',
            bitrateKbps: 256,
            contentLengthBytes: 0,
            platform: MusicPlatformSource.soundCloud,
            isDirectDownloadable: true,
            requiredHttpHeaders: _streamHeaders,
            streamExpiryTime: DateTime.now().add(const Duration(hours: 2)),
          );
          _directStreamCache[track.id] = result;
          return result;
        }
      } catch (e) {
        debugPrint('[ResonX SoundCloud Stream Error] $e');
      }
    }

    return DirectAudioStreamResult(
      directUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      audioFormat: 'mp3',
      bitrateKbps: 320,
      contentLengthBytes: 0,
      platform: MusicPlatformSource.fallbackCdn,
      isDirectDownloadable: false,
      requiredHttpHeaders: _streamHeaders,
      streamExpiryTime: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  Future<String> resolveAudioStreamUrl(Track track) async {
    final result = await resolveDirectAudioStream(track);
    return result.directUrl;
  }

  // ---------------------------------------------------------------------------
  // SYNCHRONIZOWANE TEKSTY PIOSENEK (LRCLIB)
  // ---------------------------------------------------------------------------

  Future<List<ResonXLrcLine>> fetchSynchronizedLyrics(Track track) async {
    if (_lyricsCache.containsKey(track.id)) {
      return _lyricsCache[track.id]!;
    }

    try {
      final cleanTitle = _sanitizeSearchQuery(track.title);
      final cleanArtist = _sanitizeSearchQuery(track.artist);

      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
          'duration': track.durationSeconds,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data != null) {
        final syncedText = response.data['syncedLyrics']?.toString() ?? '';
        if (syncedText.isNotEmpty) {
          final lines = _parseLrc(syncedText);
          _lyricsCache[track.id] = lines;
          return lines;
        }
      }
    } catch (_) {}

    return [];
  }

  List<ResonXLrcLine> _parseLrc(String lrcText) {
    final List<ResonXLrcLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcText.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3)!;
        final millis = fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);

        final timestamp = Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
        final text = match.group(4)?.trim() ?? '';
        lines.add(ResonXLrcLine(timestamp: timestamp, text: text));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  String _sanitizeSearchQuery(String text) {
    return text
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\..*|feat\..*|official|video|audio', caseSensitive: false), '')
        .trim();
  }

  void purgeAllCache() {
    _searchQueryCache.clear();
    _directStreamCache.clear();
    _lyricsCache.clear();
    _artistDiscographyCache.clear();
  }

  Map<String, dynamic> getDiagnostics() {
    return {
      'cachedSearchQueries': _searchQueryCache.length,
      'cachedStreams': _directStreamCache.length,
      'cachedLyrics': _lyricsCache.length,
      'totalRequestsExecuted': _totalNetworkRequests,
      'totalCacheHits': _cacheHits,
    };
  }

  void dispose() {
    _dio.close();
  }
}