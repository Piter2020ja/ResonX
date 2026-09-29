import 'package:flutter/foundation.dart';
import '../models/track.dart';

class MoodMatrixService extends ChangeNotifier {
  static final MoodMatrixService instance = MoodMatrixService._();
  MoodMatrixService._();

  String _currentMood = 'Energetyczny / Workout';
  String get currentMood => _currentMood;

  final Map<String, List<String>> moodCategories = {
    'Energetyczny / Workout': ['phonk', 'gym', 'workout', 'bass', 'hard', 'fast', 'techno', 'trap', 'speed'],
    'Skupienie / Coding': ['lo-fi', 'ambient', 'synthwave', 'focus', 'study', 'code', 'chill', 'instrumental'],
    'Relaks / Chill': ['acoustic', 'jazz', 'r&b', 'chillout', 'relax', 'peace', 'smooth', 'slow'],
    'Melancholia / Night': ['sad', 'piano', 'dark', 'indie', 'night', 'rain', 'slowed', 'reverb', 'lonely'],
  };

  void setMood(String mood) {
    if (moodCategories.containsKey(mood)) {
      _currentMood = mood;
      notifyListeners();
      debugPrint('[ResonX MoodMatrix] Nastrój zmieniony na: $_currentMood');
    }
  }

  // Prawdziwy, działający algorytm filtrowania utworów na podstawie nastroju i tagów/tytułów
  List<Track> filterTracksByMood(List<Track> allTracks) {
    debugPrint('[ResonX MoodMatrix] Filtrowanie utworów dla nastroju: $_currentMood');
    
    final keywords = moodCategories[_currentMood] ?? [];
    if (keywords.isEmpty) return allTracks;

    final filtered = allTracks.where((track) {
      final titleLower = track.title.toLowerCase();
      final artistLower = track.artist.toLowerCase();
      final albumLower = track.album.toLowerCase();

      // Sprawdzamy czy którykolwiek słów kluczowych nastroju pasuje do tytułu, artysty lub albumu
      for (final kw in keywords) {
        if (titleLower.contains(kw) || artistLower.contains(kw) || albumLower.contains(kw)) {
          return true;
        }
      }
      return false;
    }).toList();

    // Jeśli algorytm nie znajdzie bezpośrednich dopasowań słownych, zwracamy przynajmniej część biblioteki, żeby użytkownik nie widział pustej listy
    if (filtered.isEmpty && allTracks.isNotEmpty) {
      debugPrint('[ResonX MoodMatrix] Brak bezpośrednich słów kluczowych, zwracam domyślną pulę nastroju.');
      return allTracks.take(15).toList();
    }

    return filtered;
  }
}