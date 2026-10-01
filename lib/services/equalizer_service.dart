import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_player_service.dart';

class EqualizerService extends ChangeNotifier {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._() {
    _loadLocalSettings();
  }

  static const List<String> bandFrequencies = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  static const List<int> bandFrequencyInts = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
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

  // ---------------------------------------------------------------------------
  // CZYSZCZENIE I LOKALNY ZAPIS JSON W PLIKU URZĄDZENIA (ZERO BAZ DANYCH)
  // ---------------------------------------------------------------------------

  Future<File> _getLocalConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/resonx_equalizer_local.json');
    return file;
  }

  Future<void> _loadLocalSettings() async {
    try {
      final file = await _getLocalConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);
          _isEnabled = data['is_enabled'] as bool? ?? true;
          _bassBoost = (data['bass_boost'] as num?)?.toDouble() ?? 0.0;
          _surround = (data['surround'] as num?)?.toDouble() ?? 0.0;
          _currentPreset = data['current_preset'] as String? ?? 'Flat';

          if (data['band_gains'] is List) {
            final List gains = data['band_gains'] as List;
            for (int i = 0; i < _bandGains.length && i < gains.length; i++) {
              if (gains[i] is num) {
                _bandGains[i] = (gains[i] as num).toDouble();
              }
            }
          }

          notifyListeners();
          applyFilters();
          debugPrint('[ResonX Equalizer] Załadowano lokalny stan korektora z pliku JSON.');
        }
      }
    } catch (e) {
      debugPrint('[ResonX Equalizer] Błąd lokalnego odczytu: $e');
    }
  }

  Future<void> _saveLocalSettings() async {
    try {
      final file = await _getLocalConfigFile();
      final Map<String, dynamic> data = {
        'is_enabled': _isEnabled,
        'bass_boost': _bassBoost,
        'surround': _surround,
        'current_preset': _currentPreset,
        'band_gains': _bandGains,
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[ResonX Equalizer] Błąd lokalnego zapisu: $e');
    }
  }

  // --- KOMPATYBILNOŚĆ Z UI (SettingsScreen & HomeScreen) ---

  void setEnabled(bool value) {
    _isEnabled = value;
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void toggleEnabled(bool value) {
    _isEnabled = value;
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void setBand(int index, double gain) {
    int targetIndex = (index * 2).clamp(0, _bandGains.length - 1);
    setBandGain(targetIndex, gain);
    if (targetIndex + 1 < _bandGains.length) {
      setBandGain(targetIndex + 1, gain);
    }
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain.clamp(-12.0, 12.0);
      _currentPreset = 'Custom';
      applyFilters();
      _saveLocalSettings();
      notifyListeners();
    }
  }

  void setBandByFrequency(String freqLabel, double gain) {
    final idx = bandFrequencies.indexOf(freqLabel);
    if (idx != -1) {
      setBandGain(idx, gain);
    }
  }

  double getBandGainByFrequency(String freqLabel) {
    final idx = bandFrequencies.indexOf(freqLabel);
    if (idx != -1) {
      return _bandGains[idx];
    }
    return 0.0;
  }

  void setPreset(List<double> gains) {
    _currentPreset = 'Custom';
    for (int i = 0; i < gains.length; i++) {
      int targetIndex = (i * 2).clamp(0, _bandGains.length - 1);
      _bandGains[targetIndex] = gains[i].clamp(-12.0, 12.0);
      if (targetIndex + 1 < _bandGains.length) {
        _bandGains[targetIndex + 1] = gains[i].clamp(-12.0, 12.0);
      }
    }
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  double get band60Hz => _bandGains[1];
  double get band230Hz => _bandGains[3];
  double get band910Hz => _bandGains[5];
  double get band4kHz => _bandGains[7];
  double get band14kHz => _bandGains[9];

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 10.0);
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void setSurround(double value) {
    _surround = value.clamp(0.0, 10.0);
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void applyPreset(String presetName) {
    _currentPreset = presetName;
    switch (presetName) {
      case 'Bass Boost':
        _setAllGains([7.0, 6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0]);
        _bassBoost = 6.0;
        break;
      case 'Hip-Hop Punch':
        _setAllGains([5.0, 4.2, 2.5, 0.0, -1.2, 1.5, 2.8, 3.6, 4.2, 5.0]);
        _bassBoost = 4.0;
        break;
      case 'Rock':
        _setAllGains([4.5, 3.0, -1.0, -1.5, 0.5, 2.0, 4.0, 5.0, 4.5, 4.0]);
        _bassBoost = 2.0;
        break;
      case 'Electronic':
        _setAllGains([5.0, 4.0, 2.0, 0.0, -1.0, 1.5, 3.0, 4.5, 5.0, 4.0]);
        _bassBoost = 4.0;
        break;
      case 'Crisp Vocals':
      case 'Vocal':
        _setAllGains([-2.0, -1.5, -0.5, 1.0, 2.5, 4.5, 4.0, 2.5, 1.0, 0.0]);
        _bassBoost = 0.0;
        break;
      case 'Flat':
      case 'Flat Studio':
      default:
        _setAllGains(List.generate(10, (_) => 0.0));
        _bassBoost = 0.0;
        _surround = 0.0;
        break;
    }
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void resetToDefaultFlat() {
    _currentPreset = 'Flat Studio';
    _setAllGains(List.generate(10, (_) => 0.0));
    _bassBoost = 0.0;
    _surround = 0.0;
    applyFilters();
    _saveLocalSettings();
    notifyListeners();
  }

  void _setAllGains(List<double> gains) {
    for (int i = 0; i < _bandGains.length && i < gains.length; i++) {
      _bandGains[i] = gains[i];
    }
  }

  // ---------------------------------------------------------------------------
  // NATYWNE ZASTOSOWANIE FILTRÓW W POTOKU MPV
  // ---------------------------------------------------------------------------

  Future<void> applyFilters() async {
    try {
      final player = AudioPlayerService.instance.rawPlayer;
      final dynamic nativePlatform = player.platform;

      if (!_isEnabled) {
        if (nativePlatform != null) {
          try {
            await (nativePlatform as dynamic).setProperty('af', '');
          } catch (_) {
            try {
              (nativePlatform as dynamic).command?.call(['set_property', 'af', '']);
            } catch (_) {}
          }
        }
        debugPrint('[ResonX Equalizer] Filtry audio wyczyszczone (EQ wyłączony).');
        return;
      }

      final List<String> activeFilters = [];

      for (int i = 0; i < _bandGains.length; i++) {
        final gain = _bandGains[i];
        if (gain != 0.0) {
          final freq = bandFrequencyInts[i];
          activeFilters.add('equalizer=f=$freq:width_type=o:w=1.0:g=${gain.toStringAsFixed(1)}');
        }
      }

      if (_bassBoost > 0.0) {
        final boostGain = (_bassBoost * 0.8).clamp(0.0, 10.0);
        activeFilters.add('equalizer=f=60:width_type=h:w=50:g=${boostGain.toStringAsFixed(1)}');
      }

      if (_surround > 0.0) {
        activeFilters.add('extrastereo=m=${(1.0 + (_surround * 0.1)).toStringAsFixed(2)}');
      }

      final String filterString = activeFilters.isNotEmpty ? activeFilters.join(',') : '';

      if (nativePlatform != null) {
        try {
          await (nativePlatform as dynamic).setProperty('af', filterString);
        } catch (_) {
          try {
            (nativePlatform as dynamic).command?.call(['set_property', 'af', filterString]);
          } catch (_) {}
        }
      }

      debugPrint('[ResonX Equalizer DSP] Zastosowano natywny filtr MPV: af="$filterString"');
    } catch (e) {
      debugPrint('[ResonX Equalizer Error] Błąd podczas nakładania filtru: $e');
    }
  }
}