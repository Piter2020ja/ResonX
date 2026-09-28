import 'package:flutter/foundation.dart';

class EqualizerService extends ChangeNotifier {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  static const List<String> bandFrequencies = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  double _bassBoost = 0.0;
  double get bassBoost => _bassBoost;

  double _surround = 0.0;
  double get surround => _surround;

  List<String> get bands => bandFrequencies;

  final List<double> _bandGains = List.generate(10, (_) => 0.0);
  List<double> get bandGains => List.unmodifiable(_bandGains);

  String _currentPreset = 'Flat';
  String get currentPreset => _currentPreset;

  // --- KOMPATYBILNOŚĆ Z NOWYM UI (Metody żądane przez SettingsScreen) ---
  void setEnabled(bool value) {
    _isEnabled = value;
    notifyListeners();
  }

  void setBand(int index, double gain) {
    // Mapowanie 5 pasm z UI na 10 pasm silnika Equalizera
    int targetIndex = (index * 2).clamp(0, _bandGains.length - 1);
    setBandGain(targetIndex, gain);
    if (targetIndex + 1 < _bandGains.length) {
      setBandGain(targetIndex + 1, gain);
    }
  }

  void setPreset(List<double> gains) {
    _currentPreset = 'Custom';
    for (int i = 0; i < gains.length; i++) {
      setBand(i, gains[i]);
    }
    notifyListeners();
  }
  // ------------------------------------------------------------------

  // Gettery dla 5 głównych pasm wywoływane w suwakach SettingsScreen
  double get band60Hz => _bandGains[1];
  double get band230Hz => _bandGains[3];
  double get band910Hz => _bandGains[5];
  double get band4kHz => _bandGains[7];
  double get band14kHz => _bandGains[9];

  void toggleEnabled(bool value) {
    _isEnabled = value;
    notifyListeners();
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain.clamp(-12.0, 12.0);
      _currentPreset = 'Custom';
      notifyListeners();
    }
  }

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 10.0);
    notifyListeners();
  }

  void setSurround(double value) {
    _surround = value.clamp(0.0, 10.0);
    notifyListeners();
  }

  void applyPreset(String presetName) {
    _currentPreset = presetName;
    switch (presetName) {
      case 'Bass Boost':
        _setAllGains([6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0]);
        _bassBoost = 6.0;
        break;
      case 'Rock':
        _setAllGains([4.5, 3.0, -1.0, -1.5, 0.5, 2.0, 4.0, 5.0, 4.5, 4.0]);
        _bassBoost = 2.0;
        break;
      case 'Electronic':
        _setAllGains([5.0, 4.0, 2.0, 0.0, -1.0, 1.5, 3.0, 4.5, 5.0, 4.0]);
        _bassBoost = 4.0;
        break;
      case 'Vocal':
        _setAllGains([-2.0, -1.5, -0.5, 2.0, 4.5, 5.0, 3.5, 1.5, 0.0, -1.0]);
        _bassBoost = 0.0;
        break;
      case 'Flat':
      default:
        _setAllGains(List.generate(10, (_) => 0.0));
        _bassBoost = 0.0;
        _surround = 0.0;
        break;
    }
    notifyListeners();
  }

  void _setAllGains(List<double> gains) {
    for (int i = 0; i < _bandGains.length && i < gains.length; i++) {
      _bandGains[i] = gains[i];
    }
  }
}