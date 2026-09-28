import 'package:flutter/foundation.dart';
import '../models/track.dart';

class ListeningHistoryService extends ChangeNotifier {
  static final ListeningHistoryService instance = ListeningHistoryService._();
  ListeningHistoryService._();

  final List<Track> _history = [];
  List<Track> get history => List.unmodifiable(_history);

  void addToHistory(Track track) {
    // Usuń duplikat z historii, jeśli już tam jest, i wstaw na sam początek
    _history.removeWhere((t) => t.id == track.id);
    _history.insert(0, track);

    // Ogranicz historię do ostatnich 50 utworów
    if (_history.length > 50) {
      _history.removeLast();
    }
    notifyListeners();
    debugPrint('Dodano do historii odsłuchu: ${track.title}');
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
    debugPrint('Wyczyszczono historię odsłuchu.');
  }
}