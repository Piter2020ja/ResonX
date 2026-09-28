import 'package:flutter/foundation.dart';

class StatsAndAchievementsService extends ChangeNotifier {
  static final StatsAndAchievementsService instance = StatsAndAchievementsService._();
  StatsAndAchievementsService._();

  int _totalListeningMinutes = 1420;
  int get totalListeningMinutes => _totalListeningMinutes;

  int _totalTracksPlayed = 124;
  int get totalTracksPlayed => _totalTracksPlayed;

  int _favoriteTracksCount = 48;
  int get favoriteTracksCount => _favoriteTracksCount;

  // Pełna lista osiągnięć z dynamicznym systemem sprawdzania warunków
  final List<Map<String, dynamic>> _achievements = [
    {
      'id': 'night_owl',
      'title': 'Night Owl',
      'desc': 'Słuchaj muzyki po północy',
      'unlocked': true,
      'icon': '🌙',
    },
    {
      'id': 'audiophile',
      'title': 'Audiophile',
      'desc': 'Odtwórz plik w formacie Lossless FLAC / 320kbps',
      'unlocked': true,
      'icon': '🎧',
    },
    {
      'id': 'cyber_dj',
      'title': 'Cyber DJ',
      'desc': 'Użyj 10-pasmowego equalizera DSP lub efektów',
      'unlocked': true,
      'icon': '🎛️',
    },
    {
      'id': 'master_collector',
      'title': 'Master Collector',
      'desc': 'Dodaj ponad 50 utworów do ulubionych',
      'unlocked': false,
      'icon': '⭐',
    },
    {
      'id': 'ceo_resonx',
      'title': 'CEO of ResonX',
      'desc': 'Otwórz zabezpieczoną PIN-em konsolę administratora',
      'unlocked': true,
      'icon': '👑',
    },
    {
      'id': 'speed_runner',
      'title': 'Speed Runner',
      'desc': 'Zmień prędkość odtwarzania (DSP Rate) utworu',
      'unlocked': false,
      'icon': '⚡',
    },
    {
      'id': 'offline_commander',
      'title': 'Offline Commander',
      'desc': 'Pobierz utwór do pamięci podręcznej offline',
      'unlocked': false,
      'icon': '📥',
    },
    {
      'id': 'sharedrop_pioneer',
      'title': 'ShareDrop Pioneer',
      'desc': 'Udostępnij utwór lub playlistę przez ResonX Drop',
      'unlocked': false,
      'icon': '📡',
    },
  ];

  List<Map<String, dynamic>> get achievements => _achievements;

  // Dodawanie minut odsłuchu z automatycznym sprawdzaniem odznak
  void addListeningMinutes(int mins) {
    _totalListeningMinutes += mins;
    _checkTimeAchievements();
    notifyListeners();
  }

  // Rejestrowanie odtworzenia utworu
  void recordTrackPlay({bool isLossless = true}) {
    _totalTracksPlayed++;
    if (isLossless && DateTime.now().hour >= 0 && DateTime.now().hour < 4) {
      _unlockAchievement('night_owl');
    }
    notifyListeners();
  }

  // Aktualizacja liczby ulubionych utworów
  void updateFavoritesCount(int count) {
    _favoriteTracksCount = count;
    if (_favoriteTracksCount >= 50) {
      _unlockAchievement('master_collector');
    }
    notifyListeners();
  }

  // Odblokowanie konkretnego osiągnięcia na podstawie zdarzenia w aplikacji
  void unlockAchievementById(String id) {
    _unlockAchievement(id);
  }

  void _unlockAchievement(String id) {
    final index = _achievements.indexWhere((a) => a['id'] == id);
    if (index != -1 && !_achievements[index]['unlocked']) {
      _achievements[index]['unlocked'] = true;
      debugPrint('[StatsService] Odblokowano osiągnięcie: ${_achievements[index]['title']}');
      notifyListeners();
    }
  }

  void _checkTimeAchievements() {
    if (_totalListeningMinutes >= 1500) {
      _unlockAchievement('audiophile');
    }
  }

  // Resetowanie statystyk (opcjonalnie)
  void resetStats() {
    _totalListeningMinutes = 0;
    _totalTracksPlayed = 0;
    notifyListeners();
  }
}