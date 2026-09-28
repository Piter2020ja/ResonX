import 'package:flutter/foundation.dart';

class StatsAndAchievementsService extends ChangeNotifier {
  static final StatsAndAchievementsService instance = StatsAndAchievementsService._();
  StatsAndAchievementsService._();

  int _totalListeningMinutes = 1420;
  int get totalListeningMinutes => _totalListeningMinutes;

  final int _favoriteTracksCount = 48;
  int get favoriteTracksCount => _favoriteTracksCount;

  final List<Map<String, dynamic>> achievements = [
    {'title': 'Night Owl', 'desc': 'Słuchaj muzyki po północy', 'unlocked': true, 'icon': '🌙'},
    {'title': 'Audiophile', 'desc': 'Odtwórz plik w formacie FLAC / 320kbps', 'unlocked': true, 'icon': '🎧'},
    {'title': 'Cyber DJ', 'desc': 'Użyj 10-pasmowego equalizera i efektu 8D', 'unlocked': true, 'icon': '🎛️'},
    {'title': 'Master Collector', 'desc': 'Dodaj ponad 50 utworów do ulubionych', 'unlocked': false, 'icon': '⭐'},
    {'title': 'CEO of ResonX', 'desc': 'Otwórz ukryty panel administratora', 'unlocked': true, 'icon': '👑'},
  ];

  void addListeningMinutes(int mins) {
    _totalListeningMinutes += mins;
    notifyListeners();
  }
}