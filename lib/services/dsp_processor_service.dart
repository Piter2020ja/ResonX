import 'package:flutter/foundation.dart';

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
  DspProcessorService._();

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

  void setEnabled(bool value) {
    _isEnabled = value;
    notifyListeners();
  }

  void setBassBoost(double value) {
    _bassBoostLevel = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSpatialAudio(double value) {
    _spatialAudioLevel = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setReverbLevel(double value) {
    _reverbLevel = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setTrebleBoost(double value) {
    _trebleBoostLevel = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void set8dAudio(bool value) {
    _is8dAudioEnabled = value;
    notifyListeners();
  }

  void toggleSpatial8D([bool? value]) {
    _is8dAudioEnabled = value ?? !_is8dAudioEnabled;
    notifyListeners();
  }

  void setVocalClarity(double value) {
    _vocalClarity = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleSubBassCut([bool? value]) {
    _subBassCut = value ?? !_subBassCut;
    notifyListeners();
  }

  void toggleMono([bool? value]) {
    _monoConversion = value ?? !_monoConversion;
    notifyListeners();
  }

  void toggleNoiseGate([bool? value]) {
    _noiseGateActive = value ?? !_noiseGateActive;
    notifyListeners();
  }

  void setStereoPan(double value) {
    _stereoPan = value.clamp(-1.0, 1.0);
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
    notifyListeners();
  }

  void setBluetoothOffset(int offsetMs) {
    _bluetoothSyncOffsetMs = offsetMs.clamp(-1000, 1000);
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