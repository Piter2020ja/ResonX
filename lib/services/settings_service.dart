import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();

  SettingsService._internal() {
    loadSettings();
  }

  bool _ignoreAudioFocus = true; // Domyślnie: muzyka gra dalej podczas scrollowania TikToka/Reels
  bool _pauseOnPhoneCall = true;  // Automatyczna pauza podczas rozmowy telefonicznej
  bool _autoDownloadFavorites = false;
  String _preferredAudioQuality = 'HQ (320kbps)';
  
  // --- Prawdziwy stan oszczędzania baterii zintegrowany z plikiem konfiguracyjnym ---
  bool _batterySaverEnabled = false;

  bool get ignoreAudioFocus => _ignoreAudioFocus;
  bool get pauseOnPhoneCall => _pauseOnPhoneCall;
  bool get autoDownloadFavorites => _autoDownloadFavorites;
  String get preferredAudioQuality => _preferredAudioQuality;
  bool get batterySaverEnabled => _batterySaverEnabled;

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final resonxDir = Directory('${dir.path}/ResonXStorage');
    if (!resonxDir.existsSync()) {
      resonxDir.createSync(recursive: true);
    }
    return File('${resonxDir.path}/app_settings.json');
  }

  Future<void> loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);
          _ignoreAudioFocus = data['ignore_audio_focus'] as bool? ?? true;
          _pauseOnPhoneCall = data['pause_on_phone_call'] as bool? ?? true;
          _autoDownloadFavorites = data['auto_download_fav'] as bool? ?? false;
          _preferredAudioQuality = data['preferred_quality'] as String? ?? 'HQ (320kbps)';
          _batterySaverEnabled = data['battery_saver_enabled'] as bool? ?? false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[ResonX Settings] Błąd ładowania ustawień: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _getSettingsFile();
      final Map<String, dynamic> data = {
        'ignore_audio_focus': _ignoreAudioFocus,
        'pause_on_phone_call': _pauseOnPhoneCall,
        'auto_download_fav': _autoDownloadFavorites,
        'preferred_quality': _preferredAudioQuality,
        'battery_saver_enabled': _batterySaverEnabled,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[ResonX Settings] Błąd zapisu ustawień: $e');
    }
  }

  Future<void> setIgnoreAudioFocus(bool value) async {
    _ignoreAudioFocus = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setPauseOnPhoneCall(bool value) async {
    _pauseOnPhoneCall = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAutoDownloadFavorites(bool value) async {
    _autoDownloadFavorites = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setPreferredQuality(String quality) async {
    _preferredAudioQuality = quality;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setBatterySaverEnabled(bool value) async {
    _batterySaverEnabled = value;
    notifyListeners();
    await _saveSettings();
    debugPrint('[ResonX BatterySaver] Tryb oszczędzania baterii zapisany: $value');
  }
}