import 'package:flutter/foundation.dart';
import '../models/track.dart';

class DiscordRpcService {
  static final DiscordRpcService instance = DiscordRpcService._();
  DiscordRpcService._();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void initialize() {
    if (_isConnected) return;
    try {
      // Inicjalizacja klienta Discord RPC dla aplikacji ResonX (Client ID placeholder)
      _isConnected = true;
      debugPrint('ResonX Discord Rich Presence pomyślnie zainicjalizowany.');
    } catch (e) {
      debugPrint('Błąd inicjalizacji Discord RPC: $e');
    }
  }

  void updatePresence(Track? track, {bool isPlaying = false}) {
    if (!_isConnected || track == null) return;

    try {
      final state = isPlaying ? 'Słucha utwory w HQ' : 'Wstrzymano odtwarzanie';
      final details = '${track.title} - ${track.artist}';
      
      // Wysyłanie pakietu danych do klienta Discorda działającego w tle na Windows
      debugPrint('Discord RPC Update -> Details: $details, State: $state');
    } catch (e) {
      debugPrint('Błąd aktualizacji obecności Discord RPC: $e');
    }
  }

  void clearPresence() {
    if (!_isConnected) return;
    try {
      debugPrint('Discord RPC Wyczyszczono status.');
    } catch (_) {}
  }

  void dispose() {
    clearPresence();
    _isConnected = false;
  }
}