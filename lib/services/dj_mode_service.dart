import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class DjModeService extends ChangeNotifier {
  static final DjModeService instance = DjModeService._();
  DjModeService._();

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  bool _isSyncLocked = false;
  bool get isSyncLocked => _isSyncLocked;

  void setPlaybackSpeed(AudioPlayer player, double speed) {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    player.setSpeed(_playbackSpeed);
    notifyListeners();
    debugPrint('Tryb DJ: Zmieniono prędkość odtwarzania na ${_playbackSpeed}x');
  }

  void toggleSyncLock(bool val) {
    _isSyncLocked = val;
    notifyListeners();
    debugPrint('Tryb DJ: Synchronizacja bitów (Beatmatching Lock) -> $_isSyncLocked');
  }

  void resetPitch(AudioPlayer player) {
    _playbackSpeed = 1.0;
    player.setSpeed(1.0);
    notifyListeners();
  }
}