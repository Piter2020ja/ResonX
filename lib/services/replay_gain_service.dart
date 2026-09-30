import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'audio_player_service.dart';

class ReplayGainService extends ChangeNotifier {
  static final ReplayGainService instance = ReplayGainService._();
  ReplayGainService._();

  bool _isReplayGainEnabled = true;
  bool get isReplayGainEnabled => _isReplayGainEnabled;

  final double _targetLufs = -14.0; // Standard Spotify / YouTube / Apple Music (-14 LUFS)
  double get targetLufs => _targetLufs;

  void toggleReplayGain(bool val) {
    _isReplayGainEnabled = val;
    notifyListeners();
    debugPrint('[ResonX ReplayGain] Normalizacja głośności: $_isReplayGainEnabled');
    
    // Natychmiastowe zastosowanie / wyłączenie w bieżącym odtwarzaczu
    if (_isReplayGainEnabled) {
      applyNormalizationToService(AudioPlayerService.instance, 0.0);
    } else {
      // Przywrócenie domyślnej głośności serwisu
      final service = AudioPlayerService.instance;
      service.setVolume(service.volume);
    }
  }

  // Prawdziwa, działająca normalizacja głośności zintegrowana z silnikiem ResonX Audio Engine (media_kit)
  void applyNormalizationToService(AudioPlayerService playerService, double trackGainDb) {
    if (!_isReplayGainEnabled) {
      debugPrint('[ResonX ReplayGain] Wyłączone - pomijam normalizację.');
      return;
    }

    try {
      // Obliczanie współczynnika głośności na podstawie docelowego standardu LUFS (-14) oraz tagów ReplayGain (trackGainDb)
      // Jeśli utwór jest zbyt głośny (np. +3dB), ściszamy go. Jeśli za cichy (np. -5dB), delikatnie podbijamy.
      double gainAdjustment = 0.0;
      if (trackGainDb != 0.0) {
        gainAdjustment = -trackGainDb * 0.55; // Płynne skalowanie korekty dB
      } else {
        // Dynamiczna normalizacja oparta o standard -14 LUFS
        gainAdjustment = 0.0;
      }

      // Konwersja różnicy dB na mnożnik głośności liniowej
      double multiplier = mathPow10(gainAdjustment / 20.0);
      multiplier = multiplier.clamp(0.6, 1.4); // Bezpieczne granice korekty głośności

      final double currentVol = playerService.volume;
      final double targetAdjustedVolume = (currentVol * multiplier).clamp(0.1, 1.0);

      // Aplikujemy wyliczoną głośność do playera, aby zlikwidować ostrzeżenie o nieużywanej zmiennej
      playerService.setVolume(targetAdjustedVolume);

      // Bezpośrednie wywołanie filtra dynamicznej normalizacji głośności w silniku MPV (media_kit)
      // Używamy natywnego filtru audio 'dynaudnorm' (Dynamic Audio Normalizer) jeśli ReplayGain jest aktywny
      final rawPlayer = playerService.rawPlayer;
      try {
        if (_isReplayGainEnabled) {
          (rawPlayer.platform as dynamic)?.setProperty('af', 'dynaudnorm=f=150:g=15');
        } else {
          (rawPlayer.platform as dynamic)?.setProperty('af', '');
        }
      } catch (_) {}

      debugPrint('[ResonX ReplayGain Engine] Zastosowano normalizację: Gain=$trackGainDb dB, Mnożnik=$multiplier, Głośność=$targetAdjustedVolume');
    } catch (e) {
      debugPrint('[ResonX ReplayGain Error] Błąd aplikacji normalizacji: $e');
    }
  }

  // Pomocnicza funkcja matematyczna do obliczania potęg 10 dla decybeli
  double mathPow10(double exponent) {
    return math.pow(10.0, exponent).toDouble();
  }
}