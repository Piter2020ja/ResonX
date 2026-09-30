import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

enum MusicPlatformSource {
  soundCloud,
  youtubeMusic,
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
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
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
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
    'Referer': 'https://music.youtube.com/',
  };

  // ---------------------------------------------------------------------------
  // DYNAMICZNE POBIERANIE TOKENA SOUNDCLOUD
  // ---------------------------------------------------------------------------

  Future<String> _getClientId() async {
    if (_dynamicClientId != null &&
        _clientIdExpiry != null &&
        DateTime.now().isBefore(_clientIdExpiry!)) {
      return _dynamicClientId!;
    }

    try {
      final homeResponse = await _dio.get('https://soundcloud.com');
      final html = homeResponse.data.toString();

      final scriptRegex = RegExp(r'<script\s+crossorigin\s+src="([^"]+\.js)"');
      final matches = scriptRegex.allMatches(html).toList();

      for (final match in matches.reversed) {
        final jsUrl = match.group(1);
        if (jsUrl != null && jsUrl.isNotEmpty) {
          try {
            final jsResponse = await _dio.get(jsUrl);
            final jsCode = jsResponse.data.toString();

            final idRegex = RegExp(r'client_id[:=]["\x27]([a-zA-Z0-9]{32})["\x27]');
            final idMatch = idRegex.firstMatch(jsCode);

            if (idMatch != null) {
              _dynamicClientId = idMatch.group(1);
              _clientIdExpiry = DateTime.now().add(const Duration(hours: 12));
              debugPrint('[ResonX SoundCloud Engine] Wykryto aktywny token: $_dynamicClientId');
              return _dynamicClientId!;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('[ResonX SoundCloud] Błąd automatycznego tokena: $e');
    }

    _dynamicClientId ??= 'dFjXyWspU8Q8zU8k3m1rJ4cRjV8xL2tP';
    return _dynamicClientId!;
  }

  // ---------------------------------------------------------------------------
  // RANKING TRAFNOŚCI
  // ---------------------------------------------------------------------------

  int _calculateTrackRelevanceScore(Track track, String originalQuery) {
    int score = 0;
    final query = originalQuery.toLowerCase().trim();
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();

    if (track.isOfficial) {
      score += 100;
    }

    if (artist == query) {
      score += 90;
    } else if (artist.contains(query) || query.contains(artist)) {
      score += 50;
    }

    if (title == query) {
      score += 80;
    } else if (title.startsWith(query)) {
      score += 40;
    } else if (title.contains(query)) {
      score += 25;
    }

    final junkWords = ['cover', 'remix', 'karaoke', 'instrumental', 'slowed', 'reverb', 'bass boosted', 'tribute'];
    for (final junk in junkWords) {
      if (title.contains(junk) && !query.contains(junk)) {
        score -= 120;
      }
    }

    if (track.durationSeconds >= 90 && track.durationSeconds <= 360) {
      score += 20;
    } else if (track.durationSeconds > 600) {
      score -= 60;
    }

    return score;
  }

  // ---------------------------------------------------------------------------
  // WYSZUKIWANIE BEZPOŚREDNIE PRZEZ YOUTUBE MUSIC INNERTUBE (WEB SPOOFING)
  // ---------------------------------------------------------------------------

  Future<List<Track>> _searchYouTubeWebDirect(String query, int limit) async {
    try {
      final List<Track> tracks = [];
      final response = await _dio.post(
        'https://music.youtube.com/youtubei/v1/search',
        queryParameters: {'prettyPrint': 'false'},
        data: {
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240905.01.00',
              'hl': 'pl',
              'gl': 'PL',
            },
          },
          'query': query,
          'params': 'EgWKAQIIAWoSEAMQBBAJEAoQBRAREBUREA0%3D', // Filtrowanie na utwory muzyczne
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.data != null) {
        final contents = response.data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
        
        if (contents != null) {
          for (final section in contents) {
            final musicShelf = section['musicShelfRenderer']?['contents'] as List?;
            if (musicShelf != null) {
              for (final renderer in musicShelf) {
                final trackRenderer = renderer['musicResponsiveListItemRenderer'];
                if (trackRenderer != null) {
                  final flexColumns = trackRenderer['flexColumns'] as List?;
                  if (flexColumns == null || flexColumns.isEmpty) continue;

                  // Tytuł
                  final titleRun = flexColumns[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0];
                  final title = titleRun?['text']?.toString() ?? 'Nieznany utwór';
                  final navigationEndpoint = titleRun?['navigationEndpoint'];
                  final videoId = navigationEndpoint?['watchEndpoint']?['videoId']?.toString() ?? '';

                  if (videoId.isEmpty) continue;

                  // Wykonawca
                  String artist = 'Oficjalny wykonawca';
                  String album = 'Official Studio Audio';
                  if (flexColumns.length > 1) {
                    final subtitleRuns = flexColumns[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                    if (subtitleRuns != null && subtitleRuns.isNotEmpty) {
                      artist = subtitleRuns.first['text']?.toString() ?? 'Oficjalny wykonawca';
                    }
                  }

                  // Miniaturka
                  String thumbnail = '';
                  final thumbs = trackRenderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
                  if (thumbs != null && thumbs.isNotEmpty) {
                    thumbnail = thumbs.last['url']?.toString() ?? '';
                  }

                  // Czas trwania
                  int durationSeconds = 195;
                  final fixedColumns = trackRenderer['fixedColumns'] as List?;
                  if (fixedColumns != null && fixedColumns.isNotEmpty) {
                    final durText = fixedColumns[0]['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs']?[0]?['text']?.toString() ?? '';
                    final parts = durText.split(':');
                    if (parts.length == 2) {
                      final m = int.tryParse(parts[0]) ?? 3;
                      final s = int.tryParse(parts[1]) ?? 15;
                      durationSeconds = m * 60 + s;
                    }
                  }

                  tracks.add(
                    Track(
                      id: 'yt_$videoId',
                      title: title,
                      artist: artist.replaceAll(' - Topic', '').trim(),
                      album: album,
                      durationSeconds: durationSeconds,
                      coverUrl: thumbnail,
                      audioUrl: 'https://www.youtube.com/watch?v=$videoId',
                      isOfficial: true,
                      bitrate: 320,
                      fileFormat: 'OPUS HQ',
                    ),
                  );

                  if (tracks.length >= limit) break;
                }
              }
            }
            if (tracks.length >= limit) break;
          }
        }
      }
      return tracks;
    } catch (e) {
      debugPrint('[ResonX YouTube Web Search Error] $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // GŁÓWNA METODA WYSZUKIWANIA
  // ---------------------------------------------------------------------------

  Future<List<Track>> searchTracks(
    String query, {
    int targetResultsCount = 30,
    bool includeYouTube = true,
    bool includeSoundCloud = true,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    if (_searchQueryCache.containsKey(cleanQuery)) {
      _cacheHits++;
      return _searchQueryCache[cleanQuery]!;
    }

    _totalNetworkRequests++;
    debugPrint('[ResonX Search Engine] Wyszukiwanie Web Innertube dla: "$cleanQuery"');

    final List<Track> combinedTracks = [];

    if (includeYouTube) {
      try {
        final ytResults = await _searchYouTubeWebDirect(cleanQuery, targetResultsCount);
        combinedTracks.addAll(ytResults);
      } catch (e) {
        debugPrint('[ResonX Search Engine] Błąd YouTube Web: $e');
      }
    }

    if (includeSoundCloud) {
      try {
        final clientId = await _getClientId();
        final response = await _dio.get(
          'https://api-v2.soundcloud.com/search/tracks',
          queryParameters: {
            'q': cleanQuery,
            'client_id': clientId,
            'limit': targetResultsCount,
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.data != null) {
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
                  album: 'SoundCloud',
                  durationSeconds: durationSeconds,
                  coverUrl: cover,
                  audioUrl: streamProgressiveUrl,
                  isOfficial: false,
                  bitrate: 256,
                  fileFormat: 'MP3',
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[ResonX Search Engine] Błąd SoundCloud: $e');
      }
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
    if (track.id.startsWith('yt_') || track.audioUrl.contains('youtube.com')) {
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
        return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ROZWIĄZYWANIE STRUMIENIA AUDIO PRZEZ PLAYER INNERTUBE (WEB SPOOFING)
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

    if (track.id.startsWith('yt_') || track.audioUrl.contains('youtube.com')) {
      try {
        final videoId = track.id.replaceAll('yt_', '');
        final response = await _dio.post(
          'https://music.youtube.com/youtubei/v1/player',
          queryParameters: {'prettyPrint': 'false'},
          data: {
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.20240905.01.00',
                'hl': 'pl',
                'gl': 'PL',
              },
            },
            'videoId': videoId,
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 && response.data != null) {
          final streamingData = response.data['streamingData'];
          if (streamingData != null) {
            final adaptiveFormats = streamingData['adaptiveFormats'] as List?;
            final formats = streamingData['formats'] as List?;
            
            List<dynamic> allStreams = [];
            if (adaptiveFormats != null) allStreams.addAll(adaptiveFormats);
            if (formats != null) allStreams.addAll(formats);

            // Wybieramy najlepszy strumień audio (mimetype audio)
            final audioStreams = allStreams.where((s) {
              final mime = s['mimeType']?.toString() ?? '';
              return mime.contains('audio/');
            }).toList();

            if (audioStreams.isNotEmpty) {
              audioStreams.sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
              final bestStream = audioStreams.first;
              final streamUrl = bestStream['url']?.toString() ?? '';
              final bitrate = ((bestStream['bitrate'] ?? 128000) / 1000).round();

              if (streamUrl.isNotEmpty) {
                final result = DirectAudioStreamResult(
                  directUrl: streamUrl,
                  audioFormat: 'opus',
                  bitrateKbps: bitrate,
                  contentLengthBytes: int.tryParse(bestStream['contentLength']?.toString() ?? '0') ?? 0,
                  platform: MusicPlatformSource.youtubeMusic,
                  isDirectDownloadable: true,
                  requiredHttpHeaders: _streamHeaders,
                  streamExpiryTime: DateTime.now().add(const Duration(hours: 3)),
                );

                _directStreamCache[track.id] = result;
                debugPrint('[ResonX Web Innertube Audio] Uzyskano bezpośredni strumień: $bitrate kbps');
                return result;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ResonX Web Innertube Audio Error] $e');
      }
    }

    if (track.audioUrl.isNotEmpty && !track.audioUrl.contains('youtube')) {
      final clientId = await _getClientId();
      try {
        final res = await _dio.get(
          track.audioUrl,
          queryParameters: {'client_id': clientId},
        );

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
      ).timeout(const Duration(seconds: 4));

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