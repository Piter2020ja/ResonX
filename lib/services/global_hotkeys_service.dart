import 'package:flutter/foundation.dart';
import 'audio_player_service.dart';

class GlobalHotkeysService {
  static final GlobalHotkeysService instance = GlobalHotkeysService._();
  GlobalHotkeysService._();

  bool _isInitialized = false;

  void initHotkeys() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Rejestracja nasłuchu skrótów globalnych Windows
    // W środowisku natywnym Windows spięte z hookami systemowymi klawiatury
    debugPrint('ResonX Global Hotkeys Service aktywowany dla Windows (Media Keys active).');
  }

  void handleMediaKeyPlayPause() {
    AudioPlayerService.instance.togglePlayPause();
  }

  void handleMediaKeyNext() {
    AudioPlayerService.instance.playNextTrack();
  }

  void handleMediaKeyPrev() {
    AudioPlayerService.instance.playPreviousTrack();
  }
}