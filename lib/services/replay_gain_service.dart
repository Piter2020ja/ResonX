import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_service.dart';

class ReplayGainService extends ChangeNotifier {
  static final ReplayGainService instance = ReplayGainService._();
  ReplayGainService._();

  bool _isReplayGainEnabled = true;
  bool get isReplayGainEnabled => _isReplayGainEnabled;

  final double _targetLufs = -14.0; // Standard Spotify / YouTube loudness (-14 LUFS)
  double get targetLufs => _targetLufs;

  void toggleReplayGain(bool val) {
    _isReplayGainEnabled = val;
    notifyListeners();
    debugPrint('ReplayGain (Normalizacja głośności): $_isReplayGainEnabled');
  }

  void applyNormalization(AudioPlayer player, double trackGainDb) {
    if (!_isReplayGainEnabled) {
      player.setVolume(1.0);
      return;
    }

    // Obliczanie współczynnika wzmocnienia głośności
    double volume = 1.0;
    if (trackGainDb < -1.0) {
      volume = 1.15; // Podbicie cichszych utworów
    } else if (trackGainDb > 1.0) {
      volume = 0.85; // Przyciszenie głośniejszych nagrań
    }

    player.setVolume(volume.clamp(0.1, 1.0));
    debugPrint('Zastosowano ReplayGain: Wzmocnienie $trackGainDb dB, Ustawiono głośność odtwarzacza na $volume');
  }

  // Bezpośrednia integracja z głównym silnikiem ResonX Audio Engine
  void applyNormalizationToService(AudioPlayerService playerService, double trackGainDb) {
    if (!_isReplayGainEnabled) {
      return;
    }

    double multiplier = 1.0;
    if (trackGainDb < -1.0) {
      multiplier = 1.15;
    } else if (trackGainDb > 1.0) {
      multiplier = 0.85;
    }

    final double adjustedVolume = (playerService.volume * multiplier).clamp(0.05, 1.0);
    playerService.setVolume(adjustedVolume);
    debugPrint('ReplayGain ResonX Engine: Wzmocnienie $trackGainDb dB, Dopasowano głośność do $adjustedVolume');
  }
}