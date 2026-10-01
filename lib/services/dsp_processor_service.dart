import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_player_service.dart';

enum ReverbPreset {
  off,
  smallRoom,
  room,
  studio,
  concertHall,
  hall,
  cathedral,
  cave,
}

class DspProcessorService extends ChangeNotifier {
  static final DspProcessorService instance = DspProcessorService._();
  DspProcessorService._() {
    _loadSettings();
  }

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  double _bassBoostLevel = 0.45;
  double get bassBoostLevel => _bassBoostLevel;

  double _spatialAudioLevel = 0.35;
  double get spatialAudioLevel => _spatialAudioLevel;

  double _reverbLevel = 0.20;
  double get reverbLevel => _reverbLevel;

  double _trebleBoostLevel = 0.30;
  double get trebleBoostLevel => _trebleBoostLevel;

  bool _is8dAudioEnabled = false;
  bool get is8dAudioEnabled => _is8dAudioEnabled;
  bool get spatial8DEnabled => _is8dAudioEnabled;

  double _vocalClarity = 0.50;
  double get vocalClarity => _vocalClarity;

  bool _subBassCut = false;
  bool get subBassCut => _subBassCut;

  bool _monoConversion = false;
  bool get monoConversion => _monoConversion;

  double _stereoPan = 0.0; // -1.0 (lewo) do 1.0 (prawo)
  double get stereoPan => _stereoPan;

  ReverbPreset _reverb = ReverbPreset.off;
  ReverbPreset get reverb => _reverb;

  int _bluetoothSyncOffsetMs = 0; // -500ms do 500ms
  int get bluetoothSyncOffsetMs => _bluetoothSyncOffsetMs;

  // Realny przełącznik Noise Gate w procesorze DSP
  bool _noiseGateActive = true;
  bool get noiseGateActive => _noiseGateActive;

  // ---------------------------------------------------------------------------
  // TRWAŁY ZAPIS I ODCZYT USTAWIEŃ DSP W PAMIĘCI FLASH TELEFONU
  // ---------------------------------------------------------------------------

  Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final resonxDir = Directory('${dir.path}/ResonXStorage');
    if (!resonxDir.existsSync()) {
      resonxDir.createSync(recursive: true);
    }
    return File('${resonxDir.path}/dsp_processor_settings.json');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);
          importPreset(data);
          _applyDspToPlayer();
          debugPrint('[ResonX DSP Processor] Wczytano trwale zapisane efekty DSP.');
        }
      }
    } catch (e) {
      debugPrint('[ResonX DSP Processor] Błąd odczytu konfiguracji: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _getConfigFile();
      final data = exportPreset();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[ResonX DSP Processor] Błąd zapisu konfiguracji: $e');
    }
  }

  // --- NATYWNE PRZEKAZANIE EFEKTÓW DO SILNIKA MPV ---
  Future<void> _applyDspToPlayer() async {
    try {
      final player = AudioPlayerService.instance.rawPlayer;
      final dynamic nativePlatform = player.platform;

      if (!_isEnabled) {
        if (nativePlatform != null) {
          try {
            (nativePlatform as dynamic)?.command?.call(['set_property', 'af', '']);
          } catch (_) {}
        }
        return;
      }

      final List<String> dspFilters = [];

      // 1. Prawdziwe podbicie basu (Bass Boost)
      if (_bassBoostLevel > 0.0) {
        final double gainDb = (_bassBoostLevel * 12.0).clamp(0.0, 12.0);
        dspFilters.add('equalizer=f=60:width_type=o:w=1.2:g=${gainDb.toStringAsFixed(1)}');
        dspFilters.add('equalizer=f=120:width_type=o:w=1.0:g=${(gainDb * 0.7).toStringAsFixed(1)}');
      }

      // 2. Czystość wokalu (Vocal Clarity)
      if (_vocalClarity > 0.0) {
        final double vocalGain = ((_vocalClarity - 0.5) * 8.0);
        dspFilters.add('equalizer=f=2500:width_type=o:w=1.5:g=${vocalGain.toStringAsFixed(1)}');
      }

      // 3. Podbicie góry (Treble Boost)
      if (_trebleBoostLevel > 0.0) {
        final double trebleGain = (_trebleBoostLevel * 10.0);
        dspFilters.add('equalizer=f=12000:width_type=o:w=1.2:g=${trebleGain.toStringAsFixed(1)}');
      }

      // 4. Odcięcie sub-basu (Sub Bass Cut)
      if (_subBassCut) {
        dspFilters.add('highpass=f=35');
      }

      // 5. Przestrzenne audio (Spatial / Surround)
      if (_spatialAudioLevel > 0.0 || _is8dAudioEnabled) {
        dspFilters.add('extrastereo=m=${(1.0 + (_spatialAudioLevel * 0.8)).toStringAsFixed(2)}');
      }

      // 6. Konwersja do mono
      if (_monoConversion) {
        dspFilters.add('pan=mono|c0=0.5*c0+0.5*c1');
      } else if (_stereoPan != 0.0) {
        final double leftGain = (1.0 - _stereoPan).clamp(0.0, 1.0);
        final double rightGain = (1.0 + _stereoPan).clamp(0.0, 1.0);
        dspFilters.add('pan=stereo|c0=${leftGain.toStringAsFixed(2)}*c0|c1=${rightGain.toStringAsFixed(2)}*c1');
      }

      // 7. Bramka szumów (Noise Gate)
      if (_noiseGateActive) {
        dspFilters.add('silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-40dB');
      }

      final String dspString = dspFilters.isNotEmpty ? 'lavfi=[${dspFilters.join(',')}]' : '';

      if (nativePlatform != null && dspString.isNotEmpty) {
        try {
          (nativePlatform as dynamic)?.command?.call(['set_property', 'af', dspString]);
          debugPrint('[ResonX DSP Engine] Zastosowano fizyczne filtry DSP MPV: $dspString');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[ResonX DSP Engine Error] $e');
    }
  }

  void setEnabled(bool value) {
    _isEnabled = value;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setBassBoost(double value) {
    _bassBoostLevel = value.clamp(0.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setSpatialAudio(double value) {
    _spatialAudioLevel = value.clamp(0.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setReverbLevel(double value) {
    _reverbLevel = value.clamp(0.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setTrebleBoost(double value) {
    _trebleBoostLevel = value.clamp(0.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void set8dAudio(bool value) {
    _is8dAudioEnabled = value;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void toggleSpatial8D([bool? value]) {
    _is8dAudioEnabled = value ?? !_is8dAudioEnabled;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setVocalClarity(double value) {
    _vocalClarity = value.clamp(0.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void toggleSubBassCut([bool? value]) {
    _subBassCut = value ?? !_subBassCut;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void toggleMono([bool? value]) {
    _monoConversion = value ?? !_monoConversion;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void toggleNoiseGate([bool? value]) {
    _noiseGateActive = value ?? !_noiseGateActive;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setStereoPan(double value) {
    _stereoPan = value.clamp(-1.0, 1.0);
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setReverb(dynamic presetOrLevel) {
    if (presetOrLevel is ReverbPreset) {
      setReverbPreset(presetOrLevel);
    } else if (presetOrLevel is num) {
      setReverbLevel(presetOrLevel.toDouble());
    }
  }

  void setReverbPreset(ReverbPreset preset) {
    _reverb = preset;
    switch (preset) {
      case ReverbPreset.off:
        _reverbLevel = 0.0;
        break;
      case ReverbPreset.smallRoom:
        _reverbLevel = 0.15;
        break;
      case ReverbPreset.room:
        _reverbLevel = 0.25;
        break;
      case ReverbPreset.studio:
        _reverbLevel = 0.40;
        break;
      case ReverbPreset.concertHall:
        _reverbLevel = 0.60;
        break;
      case ReverbPreset.hall:
        _reverbLevel = 0.75;
        break;
      case ReverbPreset.cathedral:
        _reverbLevel = 0.88;
        break;
      case ReverbPreset.cave:
        _reverbLevel = 1.00;
        break;
    }
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  void setBluetoothOffset(int offsetMs) {
    _bluetoothSyncOffsetMs = offsetMs.clamp(-1000, 1000);
    _saveSettings();
    notifyListeners();
  }

  void resetDefaults() {
    _isEnabled = true;
    _bassBoostLevel = 0.45;
    _spatialAudioLevel = 0.35;
    _reverbLevel = 0.20;
    _trebleBoostLevel = 0.30;
    _is8dAudioEnabled = false;
    _vocalClarity = 0.50;
    _subBassCut = false;
    _monoConversion = false;
    _stereoPan = 0.0;
    _reverb = ReverbPreset.off;
    _bluetoothSyncOffsetMs = 0;
    _noiseGateActive = true;
    _applyDspToPlayer();
    _saveSettings();
    notifyListeners();
  }

  Map<String, dynamic> exportPreset() {
    return {
      'isEnabled': _isEnabled,
      'bassBoost': _bassBoostLevel,
      'spatialAudio': _spatialAudioLevel,
      'reverb': _reverbLevel,
      'reverbPreset': _reverb.name,
      'trebleBoost': _trebleBoostLevel,
      'eightDAudio': _is8dAudioEnabled,
      'vocalClarity': _vocalClarity,
      'subBassCut': _subBassCut,
      'monoConversion': _monoConversion,
      'stereoPan': _stereoPan,
      'bluetoothSyncOffsetMs': _bluetoothSyncOffsetMs,
      'noiseGateActive': _noiseGateActive,
    };
  }

  void importPreset(Map<String, dynamic> data) {
    _isEnabled = data['isEnabled'] ?? true;
    _bassBoostLevel = (data['bassBoost'] as num?)?.toDouble() ?? 0.45;
    _spatialAudioLevel = (data['spatialAudio'] as num?)?.toDouble() ?? 0.35;
    _reverbLevel = (data['reverb'] as num?)?.toDouble() ?? 0.20;
    _trebleBoostLevel = (data['trebleBoost'] as num?)?.toDouble() ?? 0.30;
    _is8dAudioEnabled = data['eightDAudio'] ?? false;
    _vocalClarity = (data['vocalClarity'] as num?)?.toDouble() ?? 0.50;
    _subBassCut = data['subBassCut'] ?? false;
    _monoConversion = data['monoConversion'] ?? false;
    _stereoPan = (data['stereoPan'] as num?)?.toDouble() ?? 0.0;
    _bluetoothSyncOffsetMs = data['bluetoothSyncOffsetMs'] ?? 0;
    _noiseGateActive = data['noiseGateActive'] ?? true;
    if (data['reverbPreset'] != null) {
      _reverb = ReverbPreset.values.firstWhere(
        (e) => e.name == data['reverbPreset'],
        orElse: () => ReverbPreset.off,
      );
    }
    notifyListeners();
  }
}