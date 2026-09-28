import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import 'audio_player_service.dart';

class SmartFeaturesService extends ChangeNotifier {
  static final SmartFeaturesService instance = SmartFeaturesService._();
  SmartFeaturesService._();

  final List<Track> _playbackHistory = [];
  List<Track> get playbackHistory => List.unmodifiable(_playbackHistory);

  Timer? _alarmTimer;
  DateTime? _alarmTime;
  DateTime? get alarmTime => _alarmTime;

  bool _isPartyModeActive = false;
  bool get isPartyModeActive => _isPartyModeActive;
  String _partyRoomCode = '';
  String get partyRoomCode => _partyRoomCode;

  void logTrackPlayed(Track track) {
    _playbackHistory.removeWhere((t) => t.id == track.id);
    _playbackHistory.insert(0, track);
    if (_playbackHistory.length > 500) {
      _playbackHistory.removeLast();
    }
    notifyListeners();
  }

  List<Track> generateSmartShuffle(List<Track> sourceList) {
    final List<Track> sorted = List.from(sourceList);
    sorted.sort((a, b) => b.playCount.compareTo(a.playCount));

    final random = Random();
    final List<Track> result = [];
    final List<Track> pool = List.from(sorted);

    while (pool.isNotEmpty) {
      final index = (random.nextDouble() * random.nextDouble() * pool.length).toInt();
      result.add(pool.removeAt(index));
    }
    return result;
  }

  List<Track> filterByMood(List<Track> tracks, String mood) {
    switch (mood.toLowerCase()) {
      case 'energetic':
        return tracks.where((t) => t.bitrate >= 320 || t.durationSeconds < 240).toList();
      case 'calm':
        return tracks.where((t) => t.durationSeconds >= 240).toList();
      case 'study':
        return tracks.where((t) => !t.title.toLowerCase().contains('drop')).toList();
      default:
        return tracks;
    }
  }

  void scheduleSmartAlarm(DateTime targetTime, Playlist playlist) {
    _alarmTimer?.cancel();
    _alarmTime = targetTime;
    final now = DateTime.now();

    Duration initialDelay = targetTime.difference(now);
    if (initialDelay.isNegative) {
      initialDelay += const Duration(days: 1);
    }

    _alarmTimer = Timer(initialDelay, () {
      if (playlist.tracks.isNotEmpty) {
        AudioPlayerService.instance.setQueue(playlist.tracks);
      }
      _alarmTime = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSmartAlarm() {
    _alarmTimer?.cancel();
    _alarmTime = null;
    notifyListeners();
  }

  void startPartyMode() {
    final random = Random();
    _partyRoomCode = 'RSX-${1000 + random.nextInt(9000)}';
    _isPartyModeActive = true;
    notifyListeners();
  }

  void stopPartyMode() {
    _isPartyModeActive = false;
    _partyRoomCode = '';
    notifyListeners();
  }
}