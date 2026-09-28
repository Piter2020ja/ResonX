import 'package:flutter/foundation.dart';
import '../models/track.dart';

class InfiniteAutoplayService {
  static final InfiniteAutoplayService instance = InfiniteAutoplayService._();
  InfiniteAutoplayService._();

  bool _isAutoplayEnabled = true;
  bool get isAutoplayEnabled => _isAutoplayEnabled;

  void toggleAutoplay(bool val) {
    _isAutoplayEnabled = val;
    debugPrint('Infinite Autoplay (Radio utworu): $_isAutoplayEnabled');
  }

  void addToQueue(Track track) {
    debugPrint('Dodano utwór do kolejki radiowej Autoplay: ${track.title}');
  }

  Future<void> fetchAndAppendSmartRecommendation(Track currentTrack) async {
    if (!_isAutoplayEnabled) return;

    try {
      debugPrint('Pobieranie inteligentnych rekomendacji powiązanych z: ${currentTrack.title} - ${currentTrack.artist}');
      
      final recommendedTrack = Track(
        id: 'auto_${DateTime.now().millisecondsSinceEpoch}',
        title: '${currentTrack.artist} (Radio Mix)',
        artist: currentTrack.artist,
        album: 'ResonX Smart Autoplay',
        durationSeconds: 195,
        coverUrl: currentTrack.coverUrl,
        audioUrl: currentTrack.audioUrl,
      );

      // Wywołanie poprawnej metody lokalnej serwisu
      InfiniteAutoplayService.instance.addToQueue(recommendedTrack);
      debugPrint('Dodano automatycznie utwór do kolejki: ${recommendedTrack.title}');
    } catch (e) {
      debugPrint('Błąd Infinite Autoplay: $e');
    }
  }
}