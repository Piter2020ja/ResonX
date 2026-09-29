import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import '../models/track.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'discord_rpc_service.dart';
import 'downloader_service.dart';
import 'lyrics_service.dart';
import 'settings_service.dart';

enum ResonXRepeatMode {
  off,
  all,
  one,
}

// -----------------------------------------------------------------------------
// NATYWNY SYSTEMOWY HANDLER DLA EKRANU BLOKADY I BELKI ANDROIDA (SPOTIFY STYLE)
// -----------------------------------------------------------------------------
class ResonXAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _service;

  ResonXAudioHandler(this._service);

  @override
  Future<void> play() async => await _service.resume();

  @override
  Future<void> pause() async => await _service.pause();

  @override
  Future<void> skipToNext() async => await _service.playNext();

  @override
  Future<void> skipToPrevious() async => await _service.playPrevious();

  @override
  Future<void> seek(Duration position) async => await _service.seek(position);

  @override
  Future<void> stop() async => await _service.stop();

  void updateSystemNotification({
    required Track track,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) {
    mediaItem.add(
      MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: duration > Duration.zero ? duration : null,
        artUri: track.coverUrl.isNotEmpty ? Uri.tryParse(track.coverUrl) : null,
      ),
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: duration,
        speed: _service.speed,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WRAPPER SILNIKA MEDIA_KIT
// -----------------------------------------------------------------------------
class ResonXPlayerWrapper {
  final Player _innerPlayer;
  ResonXPlayerWrapper(this._innerPlayer);

  Player get rawPlayer => _innerPlayer;

  Future<void> setUrl(String url) async {
    try {
      await _innerPlayer.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1 ResonX/1.0',
            'Referer': 'https://soundcloud.com/',
          },
        ),
        play: false,
      );
    } catch (e) {
      debugPrint('[ResonX Audio Engine] Blad w setUrl: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _innerPlayer.stop();
    } catch (e) {
      debugPrint('[ResonX Audio Engine] Blad w stop: $e');
    }
  }

  Future<void> open(Media media, {bool play = true}) => _innerPlayer.open(media, play: play);
  Future<void> play() => _innerPlayer.play();
  Future<void> pause() => _innerPlayer.pause();
  Future<void> seek(Duration position) => _innerPlayer.seek(position);
  Future<void> setVolume(double volume) => _innerPlayer.setVolume(volume);
  Future<void> setRate(double rate) => _innerPlayer.setRate(rate);
  Future<void> dispose() => _innerPlayer.dispose();

  dynamic get stream => _innerPlayer.stream;
  dynamic get state => _innerPlayer.state;
}

// -----------------------------------------------------------------------------
// GŁÓWNY SERWIS AUDIO
// -----------------------------------------------------------------------------
class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._internal();

  AudioPlayerService._internal() {
    _initEngine();
  }

  late final Player _rawPlayer;
  late final ResonXPlayerWrapper _wrappedPlayer;
  ResonXAudioHandler? _systemAudioHandler;

  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  double _volume = 0.5;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  ResonXRepeatMode _repeatMode = ResonXRepeatMode.off;
  bool _isShuffle = false;

  bool _isSpedUpActive = false;
  bool _isNightcoreActive = false;
  double _crossfadeSeconds = 3.0;
  Timer? _crossfadeTimer;
  bool _isCrossfading = false;

  bool _gaplessPlayback = true;
  double _bufferDurationSeconds = 3.0;

  final List<Track> _playlist = [];
  final List<Track> _originalOrderPlaylist = [];
  int _currentIndex = -1;

  final Set<String> _favoriteTrackIds = {};

  Timer? _sleepTimer;
  int _remainingSleepSeconds = 0;

  // ---------------------------------------------------------------------------
  // GETTERY
  // ---------------------------------------------------------------------------

  ResonXPlayerWrapper get player => _wrappedPlayer;
  Player get rawPlayer => _rawPlayer;
  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get position => _currentPosition;
  Duration get duration => _totalDuration;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get speed => _playbackSpeed;

  bool get isSpedUpActive => _isSpedUpActive;
  bool get isNightcoreActive => _isNightcoreActive;
  double get crossfadeSeconds => _crossfadeSeconds;
  bool get gaplessPlayback => _gaplessPlayback;
  double get bufferDurationSeconds => _bufferDurationSeconds;

  ResonXRepeatMode get repeatMode => _repeatMode;
  bool get isShuffle => _isShuffle;
  bool get isShuffleMode => _isShuffle;
  bool get isLoopMode => _repeatMode != ResonXRepeatMode.off;

  List<Track> get currentPlaylist => List.unmodifiable(_playlist);
  List<Track> get queue => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Set<String> get favoriteTrackIds => _favoriteTrackIds;

  bool get hasActiveSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;
  int get remainingSleepSeconds => _remainingSleepSeconds;

  Stream<Duration> get positionStream => _rawPlayer.stream.position;
  Stream<bool> get playingStream => _rawPlayer.stream.playing;
  Stream<Duration> get durationStream => _rawPlayer.stream.duration;
  Stream<double> get volumeStream => _rawPlayer.stream.volume;

  // ---------------------------------------------------------------------------
  // SYSTEMOWA INICJALIZACJA POWIADOMIENIA (MEDIA STYLE)
  // ---------------------------------------------------------------------------

  Future<void> initAudioService() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _systemAudioHandler = await AudioService.init(
          builder: () => ResonXAudioHandler(this),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.resonx.channel.audio',
            androidNotificationChannelName: 'ResonX Music Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationIcon: 'mipmap/ic_launcher',
          ),
        );
        debugPrint('[ResonX AudioService] Serwis powiadomień mediów aktywny.');
      } catch (e) {
        debugPrint('[ResonX AudioService] Błąd AudioService.init: $e');
      }
    }
  }

  void _initEngine() {
    _rawPlayer = Player(
      configuration: const PlayerConfiguration(
        title: 'ResonX Audio Engine',
        ready: null,
      ),
    );
    _wrappedPlayer = ResonXPlayerWrapper(_rawPlayer);

    _rawPlayer.setVolume(_volume * 100.0);

    // Odbieranie poleceń od pływającej wyspy poza aplikacją
    if (!kIsWeb && Platform.isAndroid) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is String) {
          if (event == 'ACTION_TOGGLE') {
            togglePlayPause();
          } else if (event == 'ACTION_NEXT') {
            playNext();
          } else if (event == 'ACTION_PREV') {
            playPrevious();
          }
        }
      });
    }

    _rawPlayer.stream.playing.listen((playing) {
      _isPlaying = playing;
      updateDiscordPresence();
      _syncSystemMediaSession();
      notifyListeners();
    });

    _rawPlayer.stream.position.listen((pos) {
      _currentPosition = pos;
      LyricsService.instance.updatePlaybackPosition(pos);
      _checkCrossfadeTrigger(pos);
      notifyListeners();
    });

    _rawPlayer.stream.duration.listen((dur) {
      if (dur > Duration.zero) {
        _totalDuration = dur;
        _syncSystemMediaSession();
        notifyListeners();
      }
    });

    _rawPlayer.stream.completed.listen((completed) {
      if (completed && !_isCrossfading) {
        _handleTrackEnded();
      }
    });

    _rawPlayer.stream.volume.listen((vol) {});

    _syncFavorites();
    DatabaseService.instance.addListener(_syncFavorites);
  }

  void _syncFavorites() {
    _favoriteTrackIds.clear();
    for (final t in DatabaseService.instance.favoriteTracks) {
      _favoriteTrackIds.add(t.id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SYNCHRONIZACJA Z SYSTEMEM: POWIADOMIENIE, EKRAN BLOKADY & FLOATING ISLAND
  // ---------------------------------------------------------------------------

  void _syncSystemMediaSession() {
    if (_currentTrack == null) return;
    try {
      _systemAudioHandler?.updateSystemNotification(
        track: _currentTrack!,
        isPlaying: _isPlaying,
        position: _currentPosition,
        duration: _totalDuration,
      );

      if (!kIsWeb && Platform.isAndroid) {
        FlutterOverlayWindow.shareData({
          'title': _currentTrack!.title,
          'artist': _currentTrack!.artist,
          'coverUrl': _currentTrack!.coverUrl,
          'isPlaying': _isPlaying,
          'position': _currentPosition.inSeconds,
          'duration': _totalDuration.inSeconds,
        });
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // ODTWARZANIE UTWORÓW
  // ---------------------------------------------------------------------------

  Future<void> setUrl(String url) async {
    await _wrappedPlayer.setUrl(url);
  }

  Future<void> stop() async {
    await _rawPlayer.stop();
    _isPlaying = false;
    _currentPosition = Duration.zero;
    updateDiscordPresence();
    _syncSystemMediaSession();
    notifyListeners();
  }

  Future<void> playTrack(Track track, {List<Track>? contextPlaylist}) async {
    _currentTrack = track;
    _currentPosition = Duration.zero;
    _isCrossfading = false;

    if (contextPlaylist != null && contextPlaylist.isNotEmpty) {
      _playlist.clear();
      _playlist.addAll(contextPlaylist);
      _originalOrderPlaylist.clear();
      _originalOrderPlaylist.addAll(contextPlaylist);
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
    } else if (!_playlist.any((t) => t.id == track.id)) {
      _playlist.add(track);
      _originalOrderPlaylist.add(track);
      _currentIndex = _playlist.length - 1;
    } else {
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
    }

    notifyListeners();

    String playUri = '';
    bool isLocalFile = false;
    if (DownloaderService.instance.isDownloadedLocally(track.id)) {
      final localPath = DownloaderService.instance.getLocalFilePath(track.id);
      if (localPath != null && File(localPath).existsSync()) {
        playUri = localPath;
        isLocalFile = true;
        debugPrint('[ResonX Audio Engine] Odtwarzanie pliku z dysku offline: $playUri');
      }
    }

    if (playUri.isEmpty) {
      try {
        final streamData = await ApiService.instance.resolveDirectAudioStream(track);
        playUri = streamData.directUrl;
      } catch (e) {
        debugPrint('[ResonX Audio Engine Error] Nie udalo sie uzyskac strumienia: $e');
        return;
      }
    }

    LyricsService.instance.loadLyricsForTrack(track);

    try {
      final Media mediaToPlay = isLocalFile
          ? Media(playUri)
          : Media(
              playUri,
              httpHeaders: {
                'User-Agent':
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1 ResonX/1.0',
                'Referer': 'https://soundcloud.com/',
                'Accept': '*/*',
                'Connection': 'keep-alive',
              },
            );

      await _rawPlayer.open(mediaToPlay, play: true);
      await _rawPlayer.setVolume(_isMuted ? 0.0 : _volume * 100.0);

      double targetSpeed = _playbackSpeed;
      if (_isNightcoreActive) {
        targetSpeed = 1.30;
      } else if (_isSpedUpActive) {
        targetSpeed = 1.25;
      }
      await _rawPlayer.setRate(targetSpeed);

      if (_crossfadeSeconds > 0) {
        _applyFadeIn();
      }

      _isPlaying = true;
      updateDiscordPresence();
      _syncSystemMediaSession();
      notifyListeners();
    } catch (e) {
      debugPrint('[ResonX Audio Engine Error] Blad podczas otwierania strumienia: $e');
    }
  }

  void setNetworkBuffer(double seconds) {
    _bufferDurationSeconds = seconds.clamp(1.0, 15.0);
    notifyListeners();
  }

  void setGaplessPlayback(bool enabled) {
    _gaplessPlayback = enabled;
    notifyListeners();
  }

  Future<void> setSpedUpMode(bool enabled, [double targetSpeed = 1.25]) async {
    _isSpedUpActive = enabled;
    if (enabled) {
      _isNightcoreActive = false;
      _playbackSpeed = targetSpeed;
    } else {
      _playbackSpeed = 1.0;
    }
    await _rawPlayer.setRate(_playbackSpeed);
    notifyListeners();
  }

  Future<void> setNightcoreMode(bool enabled) async {
    _isNightcoreActive = enabled;
    if (enabled) {
      _isSpedUpActive = false;
      _playbackSpeed = 1.32;
    } else {
      _playbackSpeed = 1.0;
    }
    await _rawPlayer.setRate(_playbackSpeed);
    notifyListeners();
  }

  void setCrossfadeDuration(double seconds) {
    _crossfadeSeconds = seconds.clamp(0.0, 12.0);
    notifyListeners();
  }

  void _checkCrossfadeTrigger(Duration currentPos) {
    if (_crossfadeSeconds <= 0.0 || _totalDuration == Duration.zero || _isCrossfading) return;

    final remaining = _totalDuration - currentPos;
    if (remaining.inMilliseconds <= (_crossfadeSeconds * 1000).toInt() && remaining.inMilliseconds > 200) {
      if (_currentIndex + 1 < _playlist.length || _repeatMode == ResonXRepeatMode.all) {
        _triggerFadeOutAndNext();
      }
    }
  }

  Future<void> _triggerFadeOutAndNext() async {
    if (_isCrossfading) return;
    _isCrossfading = true;

    int steps = 15;
    int intervalMs = ((_crossfadeSeconds * 1000) ~/ steps).clamp(50, 300);
    double volStep = _volume / steps;

    for (int i = 1; i <= steps; i++) {
      if (!_isPlaying) break;
      await Future.delayed(Duration(milliseconds: intervalMs));
      double currentVol = (_volume - (volStep * i)).clamp(0.0, 1.0);
      await _rawPlayer.setVolume(currentVol * 100.0);
    }

    await playNext();
    _isCrossfading = false;
  }

  Future<void> _applyFadeIn() async {
    await _rawPlayer.setVolume(0.0);
    int steps = 12;
    int intervalMs = 100;
    double volStep = _volume / steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: intervalMs));
      double currentVol = (volStep * i).clamp(0.0, _volume);
      await _rawPlayer.setVolume(currentVol * 100.0);
    }
  }

  // ---------------------------------------------------------------------------
  // KOLEJKA
  // ---------------------------------------------------------------------------

  void setQueue(List<Track> newTracks, {int startIndex = 0}) {
    _playlist.clear();
    _playlist.addAll(newTracks);
    _originalOrderPlaylist.clear();
    _originalOrderPlaylist.addAll(newTracks);

    if (newTracks.isNotEmpty && startIndex >= 0 && startIndex < newTracks.length) {
      _currentIndex = startIndex;
      playTrack(newTracks[startIndex]);
    } else if (newTracks.isNotEmpty) {
      _currentIndex = 0;
      playTrack(newTracks[0]);
    } else {
      _currentIndex = -1;
      _currentTrack = null;
    }
    notifyListeners();
  }

  void addToQueue(Track track) {
    if (!_playlist.any((t) => t.id == track.id)) {
      _playlist.add(track);
      _originalOrderPlaylist.add(track);
      notifyListeners();
    }
  }

  void insertNext(Track track) {
    if (_playlist.isEmpty) {
      _playlist.add(track);
      _originalOrderPlaylist.add(track);
      _currentIndex = 0;
    } else {
      final insertIndex = (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _currentIndex + 1
          : _playlist.length;
      _playlist.insert(insertIndex, track);
      _originalOrderPlaylist.insert(insertIndex, track);
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex > _playlist.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);

    if (_currentTrack != null) {
      _currentIndex = _playlist.indexWhere((t) => t.id == _currentTrack!.id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // STEROWANIE
  // ---------------------------------------------------------------------------

  Future<void> pause() async {
    await _rawPlayer.pause();
    _isPlaying = false;
    updateDiscordPresence();
    _syncSystemMediaSession();
    notifyListeners();
  }

  Future<void> resume() async {
    await _rawPlayer.play();
    _isPlaying = true;
    updateDiscordPresence();
    _syncSystemMediaSession();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration targetPosition) async {
    await _rawPlayer.seek(targetPosition);
    _currentPosition = targetPosition;
    LyricsService.instance.updatePlaybackPosition(targetPosition);
    updateDiscordPresence();
    _syncSystemMediaSession();
    notifyListeners();
  }

  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    _isMuted = _volume == 0.0;
    await _rawPlayer.setVolume(_volume * 100.0);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_isMuted) {
      _isMuted = false;
      await setVolume(_volume == 0.0 ? 0.5 : _volume);
    } else {
      _isMuted = true;
      await _rawPlayer.setVolume(0.0);
    }
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double newSpeed) async {
    _playbackSpeed = newSpeed;
    _isSpedUpActive = newSpeed > 1.0;
    await _rawPlayer.setRate(newSpeed);
    notifyListeners();
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case ResonXRepeatMode.off:
        _repeatMode = ResonXRepeatMode.all;
        break;
      case ResonXRepeatMode.all:
        _repeatMode = ResonXRepeatMode.one;
        break;
      case ResonXRepeatMode.one:
        _repeatMode = ResonXRepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void toggleLoop() => toggleRepeatMode();

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      if (_currentTrack != null) {
        final remaining = _playlist.where((t) => t.id != _currentTrack!.id).toList()..shuffle();
        _playlist.clear();
        _playlist.add(_currentTrack!);
        _playlist.addAll(remaining);
        _currentIndex = 0;
      } else {
        _playlist.shuffle();
      }
    } else {
      final cur = _currentTrack;
      _playlist.clear();
      _playlist.addAll(_originalOrderPlaylist);
      if (cur != null) {
        _currentIndex = _playlist.indexWhere((t) => t.id == cur.id);
      }
    }
    notifyListeners();
  }

  Future<void> playNextTrack() async => playNext();
  Future<void> playPreviousTrack() async => playPrevious();

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    if (_repeatMode == ResonXRepeatMode.one && _currentTrack != null) {
      await seek(Duration.zero);
      await resume();
      return;
    }

    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await playTrack(_playlist[_currentIndex]);
    } else if (_repeatMode == ResonXRepeatMode.all) {
      _currentIndex = 0;
      await playTrack(_playlist[0]);
    } else {
      await pause();
      await seek(Duration.zero);
    }
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_currentPosition.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_playlist[_currentIndex]);
    } else {
      await seek(Duration.zero);
    }
  }

  void _handleTrackEnded() {
    playNext();
  }

  Future<void> toggleFavorite(Track track) async {
    await DatabaseService.instance.toggleFavorite(track);
    _syncFavorites();
  }

  void setSleepTimer(dynamic timeOrMinutes) {
    cancelSleepTimer();

    if (timeOrMinutes is Duration) {
      _remainingSleepSeconds = timeOrMinutes.inSeconds;
    } else if (timeOrMinutes is int) {
      _remainingSleepSeconds = timeOrMinutes * 60;
    } else {
      _remainingSleepSeconds = 15 * 60;
    }

    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSleepSeconds > 0) {
        _remainingSleepSeconds--;
        notifyListeners();
      } else {
        cancelSleepTimer();
        pause();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _remainingSleepSeconds = 0;
    notifyListeners();
  }

  void updateDiscordPresence([dynamic trackOrDetails]) {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final trackToDisplay = (trackOrDetails is Track) ? trackOrDetails : _currentTrack;
        if (trackToDisplay != null) {
          DiscordRpcService.instance.updatePresence(trackToDisplay);
        } else {
          DiscordRpcService.instance.clearPresence();
        }
      } catch (_) {}
    }
  }

  void handleIncomingCallState(bool isCallOngoing) {
    if (!SettingsService.instance.pauseOnPhoneCall) return;

    if (isCallOngoing && _isPlaying) {
      pause();
      debugPrint('[ResonX Audio Focus] Polaczenie przychodzace - pauza.');
    } else if (!isCallOngoing && !_isPlaying && _currentTrack != null) {
      resume();
      debugPrint('[ResonX Audio Focus] Rozmowa zakonczona - wznowiono.');
    }
  }

  void handleTransientLoss(bool allowDuck) {
    if (SettingsService.instance.ignoreAudioFocus) {
      debugPrint('[ResonX Audio Focus] Ignorowanie focus loss.');
      return;
    }

    if (allowDuck) {
      _rawPlayer.setVolume(_volume * 30.0);
    } else {
      pause();
    }
  }

  void handleFocusGained() {
    _rawPlayer.setVolume(_volume * 100.0);
    if (!_isPlaying && _currentTrack != null) {
      resume();
    }
  }

  @override
  void dispose() {
    _crossfadeTimer?.cancel();
    _sleepTimer?.cancel();
    DatabaseService.instance.removeListener(_syncFavorites);
    _rawPlayer.dispose();
    super.dispose();
  }
}