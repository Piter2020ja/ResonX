import 'package:flutter/foundation.dart';
import '../models/track.dart';

class DuplicateFinderService {
  static final DuplicateFinderService instance = DuplicateFinderService._();
  DuplicateFinderService._();

  List<List<Track>> findDuplicates(List<Track> playlistTracks) {
    final Map<String, List<Track>> grouped = {};
    
    for (var track in playlistTracks) {
      final key = '${track.title.toLowerCase().trim()}_${track.artist.toLowerCase().trim()}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(track);
    }

    // Zwraca tylko te grupy, które mają więcej niż jeden utwór (duplikaty)
    final duplicates = grouped.values.where((list) => list.length > 1).toList();
    debugPrint('Wykryto ${duplicates.length} grup duplikatów w playliście.');
    return duplicates;
  }

  List<Track> removeDuplicates(List<Track> playlistTracks) {
    final duplicates = findDuplicates(playlistTracks);
    final Set<String> idsToRemove = {};

    for (var group in duplicates) {
      // Zachowaj pierwszy element, usuń pozostałe duplikaty
      for (int i = 1; i < group.length; i++) {
        idsToRemove.add(group[i].id);
      }
    }

    final cleanedList = playlistTracks.where((t) => !idsToRemove.contains(t.id)).toList();
    debugPrint('Usunięto duplikaty. Nowy rozmiar playlisty: ${cleanedList.length}');
    return cleanedList;
  }
}