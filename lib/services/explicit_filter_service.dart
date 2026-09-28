import 'package:flutter/foundation.dart';
import '../models/track.dart';

class ExplicitFilterService extends ChangeNotifier {
  static final ExplicitFilterService instance = ExplicitFilterService._();
  ExplicitFilterService._();

  bool _isExplicitBlocked = false;
  bool get isExplicitBlocked => _isExplicitBlocked;

  final List<String> _profanityKeywords = ['fuck', 'shit', 'cunt', 'bitch', 'kurwa', 'chuj', 'jeb'];

  void toggleExplicitBlock(bool val) {
    _isExplicitBlocked = val;
    notifyListeners();
    debugPrint('Blokada Explicit (Cenzura): $_isExplicitBlocked');
  }

  bool isTrackExplicit(Track track) {
    final text = '${track.title} ${track.artist}'.toLowerCase();
    for (var word in _profanityKeywords) {
      if (text.contains(word)) {
        return true;
      }
    }
    return false;
  }

  List<Track> filterTracks(List<Track> tracks) {
    if (!_isExplicitBlocked) return tracks;
    return tracks.where((t) => !isTrackExplicit(t)).toList();
  }
}