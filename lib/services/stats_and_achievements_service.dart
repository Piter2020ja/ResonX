import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StatsAndAchievementsService extends ChangeNotifier {
  static final StatsAndAchievementsService instance = StatsAndAchievementsService._();
  StatsAndAchievementsService._() {
    loadStats();
  }

  int _totalListeningMinutes = 0;
  int get totalListeningMinutes => _totalListeningMinutes;

  int _totalTracksPlayed = 0;
  int get totalTracksPlayed => _totalTracksPlayed;

  int _favoriteTracksCount = 0;
  int get favoriteTracksCount => _favoriteTracksCount;

  // Pełna lista osiągnięć z dynamicznym systemem sprawdzania warunków i persistencją
  final List<Map<String, dynamic>> _achievements = [
    {
      'id': 'night_owl',
      'title': 'Night Owl',
      'desc': 'Słuchaj muzyki po północy',
      'unlocked': false,
      'icon': '🌙',
    },
    {
      'id': 'audiophile',
      'title': 'Audiophile',
      'desc': 'Odtwórz plik w formacie Lossless / wysokiej jakości',
      'unlocked': false,
      'icon': '🎧',
    },
    {
      'id': 'cyber_dj',
      'title': 'Cyber DJ',
      'desc': 'Użyj 10-pasmowego equalizera DSP lub efektów',
      'unlocked': false,
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
      'unlocked': false,
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

  List<Map<String, dynamic>> get achievements => List.unmodifiable(_achievements);

  // Ścieżka do pliku zapisu statystyk i odznak
  Future<File> _getStatsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final resonxDir = Directory('${dir.path}/ResonXStorage');
    if (!resonxDir.existsSync()) {
      resonxDir.createSync(recursive: true);
    }
    return File('${resonxDir.path}/user_stats.json');
  }

  // Ładowanie zapisanych statystyk z dysku
  Future<void> loadStats() async {
    try {
      final file = await _getStatsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);
          _totalListeningMinutes = data['total_minutes'] as int? ?? 0;
          _totalTracksPlayed = data['total_tracks'] as int? ?? 0;
          _favoriteTracksCount = data['favorite_count'] as int? ?? 0;

          final unlockedIds = List<String>.from(data['unlocked_achievements'] ?? []);
          for (final a in _achievements) {
            if (unlockedIds.contains(a['id'])) {
              a['unlocked'] = true;
            }
          }
          notifyListeners();
          debugPrint('[ResonX Stats] Wczytano statystyki: ${_totalListeningMinutes} min, ${_totalTracksPlayed} utworów.');
        }
      }
    } catch (e) {
      debugPrint('[ResonX Stats Error] Błąd ładowania statystyk: $e');
    }
  }

  // Zapisywanie statystyk na dysk
  Future<void> _saveStats() async {
    try {
      final file = await _getStatsFile();
      final unlockedIds = _achievements.where((a) => a['unlocked'] == true).map((a) => a['id']).toList();
      final Map<String, dynamic> data = {
        'total_minutes': _totalListeningMinutes,
        'total_tracks': _totalTracksPlayed,
        'favorite_count': _favoriteTracksCount,
        'unlocked_achievements': unlockedIds,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[ResonX Stats Error] Błąd zapisu statystyk: $e');
    }
  }

  // Dodawanie minut odsłuchu na żywo z automatycznym sprawdzaniem odznak
  void addListeningMinutes(int mins) {
    if (mins <= 0) return;
    _totalListeningMinutes += mins;
    _checkTimeAchievements();
    notifyListeners();
    _saveStats();
  }

  // Rejestrowanie realnego odtworzenia utworu
  void recordTrackPlay({bool isLossless = true}) {
    _totalTracksPlayed++;
    
    // Warunek dla odznaki Night Owl (słuchanie między północą a 4 rano)
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 4) {
      _unlockAchievement('night_owl');
    }

    if (isLossless) {
      _unlockAchievement('audiophile');
    }

    notifyListeners();
    _saveStats();
  }

  // Aktualizacja liczby ulubionych utworów z bazy danych
  void updateFavoritesCount(int count) {
    _favoriteTracksCount = count;
    if (_favoriteTracksCount >= 50) {
      _unlockAchievement('master_collector');
    }
    notifyListeners();
    _saveStats();
  }

  // Odblokowanie konkretnego osiągnięcia na podstawie zdarzenia w aplikacji
  void unlockAchievementById(String id) {
    _unlockAchievement(id);
  }

  void _unlockAchievement(String id) {
    final index = _achievements.indexWhere((a) => a['id'] == id);
    if (index != -1 && _achievements[index]['unlocked'] == false) {
      _achievements[index]['unlocked'] = true;
      debugPrint('[ResonX Achievements] Odblokowano osiągnięcie: ${_achievements[index]['title']}');
      notifyListeners();
      _saveStats();
    }
  }

  void _checkTimeAchievements() {
    if (_totalListeningMinutes >= 120) {
      _unlockAchievement('audiophile');
    }
  }

  // Resetowanie statystyk
  void resetStats() {
    _totalListeningMinutes = 0;
    _totalTracksPlayed = 0;
    for (final a in _achievements) {
      a['unlocked'] = false;
    }
    notifyListeners();
    _saveStats();
    debugPrint('[ResonX Stats] Zresetowano statystyki i osiągnięcia.');
  }
}