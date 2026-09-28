import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_player_service.dart';

class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService instance = SleepTimerService._();
  SleepTimerService._();

  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;

  bool get isTimerActive => _remainingSeconds > 0;

  void startTimer(int minutes) {
    _countdownTimer?.cancel();
    _remainingSeconds = minutes * 60;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        // Płynne wyciszanie w ostatnich 10 sekundach (Fade Out)
        if (_remainingSeconds <= 10) {
          debugPrint('Sleep Timer Fade Out: ${_remainingSeconds}s do zatrzymania...');
        }
        notifyListeners();
      } else {
        stopTimer();
        // Zatrzymanie odtwarzacza
        AudioPlayerService.instance.togglePlayPause(); // lub dedykowana pauza
        debugPrint('Sleep Timer: Odtwarzanie zostało automatycznie zatrzymane.');
      }
    });
  }

  void stopTimer() {
    _countdownTimer?.cancel();
    _remainingSeconds = 0;
    notifyListeners();
  }
}