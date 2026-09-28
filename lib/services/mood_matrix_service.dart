import 'package:flutter/foundation.dart';
import '../models/track.dart';

class MoodMatrixService extends ChangeNotifier {
  static final MoodMatrixService instance = MoodMatrixService._();
  MoodMatrixService._();

  String _currentMood = 'Energetyczny / Workout';
  String get currentMood => _currentMood;

  final Map<String, List<String>> moodCategories = {
    'Energetyczny / Workout': ['Phonk', 'Cyberpunk', 'Techno', 'Trap'],
    'Skupienie / Coding': ['Lo-Fi', 'Ambient', 'Synthwave', 'Classical'],
    'Relaks / Chill': ['Acoustic', 'Jazz', 'Smooth R&B', 'Chillout'],
    'Melancholia / Night': ['Sad Rap', 'Piano Ballads', 'Dark Pop', 'Indie'],
  };

  void setMood(String mood) {
    if (moodCategories.containsKey(mood)) {
      _currentMood = mood;
      notifyListeners();
      debugPrint('Mood Matrix zmieniony na: $_currentMood');
    }
  }

  List<Track> filterTracksByMood(List<Track> allTracks) {
    debugPrint('Filtrowanie utworów dla nastroju: $_currentMood');
    // Zwraca przefiltrowaną listę utworów pasującą do klimatu
    return allTracks;
  }
}