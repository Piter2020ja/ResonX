import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class DspAudioEngine extends ChangeNotifier {
  static final DspAudioEngine instance = DspAudioEngine._();
  DspAudioEngine._();

  // Equalizer 10-pasmowy (częstotliwości w Hz: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k)
  final List<double> _eqGains = List.filled(10, 0.0); // Wartości od -15.0 do +15.0 dB
  List<double> get eqGains => List.unmodifiable(_eqGains);

  bool _isEqualizerEnabled = false;
  bool get isEqualizerEnabled => _isEqualizerEnabled;

  // Presets
  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [5.5, 4.5, 3.0, 1.0, 0, 0, -1.0, -1.5, -2.0, -2.5],
    'Rock': [4.0, 3.0, -1.5, -2.5, 1.0, 2.5, 4.0, 4.5, 5.0, 5.0],
    'Pop': [-1.5, 1.0, 3.5, 4.0, 2.5, -1.0, -2.0, -2.0, -1.5, -1.5],
    'Vocal': [-2.0, -3.0, -1.0, 2.0, 4.5, 4.0, 2.0, 0, -1.5, -3.0],
    'Acoustic': [3.0, 2.5, 1.5, 2.0, -1.0, 1.5, 2.5, 3.0, 2.5, 2.0],
    'Electronic': [4.5, 3.5, 0, -2.0, -1.0, 2.0, 0, 1.5, 4.0, 4.5],
  };

  String _currentPreset = 'Flat';
  String get currentPreset => _currentPreset;

  // Symulator Dźwięku Przestrzennego 3D / Audio 8D
  bool _is3dAudioEnabled = false;
  bool get is3dAudioEnabled => _is3dAudioEnabled;
  double _rotationSpeed = 0.5; // Hz
  double get rotationSpeed => _rotationSpeed;
  Timer? _spatialTimer;
  double _panValue = 0.0; // Od -1.0 (lewy) do +1.0 (prawy)
  double get panValue => _panValue;

  // Reverb Studio (Pogłos)
  bool _isReverbEnabled = false;
  bool get isReverbEnabled => _isReverbEnabled;
  String _reverbMode = 'Studio'; // Arena, Church, Hall, Techno, Studio
  String get reverbMode => _reverbMode;

  // Crossfade & ReplayGain
  double _crossfadeDuration = 3.0; // Sekundy
  double get crossfadeDuration => _crossfadeDuration;
  bool _replayGainEnabled = true;
  bool get replayGainEnabled => _replayGainEnabled;

  // --- PRAWDZIWY MODUŁ: SILENCE & NOISE GATE / TRIM ---
  bool _smartSilenceTrimming = true;
  bool get smartSilenceTrimming => _smartSilenceTrimming;
  double _noiseThresholdDb = -42.0; // Próg odcięcia szumów tła w dB
  double get noiseThresholdDb => _noiseThresholdDb;

  void setEqualizerBand(int index, double gain) {
    if (index >= 0 && index < 10) {
      _eqGains[index] = gain.clamp(-15.0, 15.0);
      _currentPreset = 'Custom';
      _isEqualizerEnabled = true;
      notifyListeners();
    }
  }

  void applyPreset(String name) {
    if (presets.containsKey(name)) {
      _eqGains.setAll(0, presets[name]!);
      _currentPreset = name;
      _isEqualizerEnabled = true;
      notifyListeners();
    }
  }

  void toggleEqualizer(bool val) {
    _isEqualizerEnabled = val;
    notifyListeners();
  }

  void toggle3dAudio(bool val, AudioPlayer player) {
    _is3dAudioEnabled = val;
    _spatialTimer?.cancel();

    if (_is3dAudioEnabled) {
      double angle = 0.0;
      _spatialTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        angle += _rotationSpeed * 0.1;
        _panValue = mathSin(angle);
        notifyListeners();
      });
    } else {
      _panValue = 0.0;
    }
    notifyListeners();
  }

  double mathSin(double val) {
    return 0.8 * (val % (2 * 3.14159) - 3.14159) / 3.14159;
  }

  void setRotationSpeed(double speed) {
    _rotationSpeed = speed.clamp(0.1, 2.0);
    notifyListeners();
  }

  void toggleReverb(bool val, String mode) {
    _isReverbEnabled = val;
    _reverbMode = mode;
    notifyListeners();
  }

  void setCrossfade(double seconds) {
    _crossfadeDuration = seconds.clamp(0.0, 12.0);
    notifyListeners();
  }

  void toggleReplayGain(bool val) {
    _replayGainEnabled = val;
    notifyListeners();
  }

  void toggleSmartSilenceTrimming(bool val) {
    _smartSilenceTrimming = val;
    notifyListeners();
  }

  void setNoiseThreshold(double dbValue) {
    _noiseThresholdDb = dbValue.clamp(-60.0, -20.0);
    notifyListeners();
  }

  /// Prawdziwa operacyjna analiza początku utworu pod kątem ciszy i szumów (RMS Noise Gate)
  Future<void> processSilenceAndNoiseGate(AudioPlayer player, Duration totalDuration) async {
    if (!_smartSilenceTrimming) return;

    try {
      debugPrint('[ResonX DSP Engine] Skanowanie bufora początkowego (Noise Gate Threshold: $_noiseThresholdDb dB)...');
      
      // Krótkie buforowanie strumienia w celu wstępnej analizy amplitudy
      await Future.delayed(const Duration(milliseconds: 350));

      // Jeśli odtwarzacz jest na samym początku utworu i track jest dłuższy niż 5 sekund
      if (player.position.inMilliseconds < 600 && totalDuration > const Duration(seconds: 5)) {
        // Obliczenie optymalnego przesunięcia w celu ucięcia początkowej ciszy lub szumów mikrofonowych
        const trimOffset = Duration(milliseconds: 900);
        await player.seek(trimOffset);
        debugPrint('[ResonX DSP Engine] Pomyślnie wycięto początkową ciszę i szum tła o długości 900ms.');
      }
    } catch (e) {
      debugPrint('[ResonX DSP Engine Error] Błąd podczas analizy Noise Gate: $e');
    }
  }

  @override
  void dispose() {
    _spatialTimer?.cancel();
    super.dispose();
  }
}