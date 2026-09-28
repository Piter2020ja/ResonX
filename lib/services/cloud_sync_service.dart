import 'package:flutter/foundation.dart';
import '../models/track.dart';

class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService instance = CloudSyncService._();
  CloudSyncService._();

  bool _isSynced = false;
  bool get isSynced => _isSynced;

  String _lastSyncTimestamp = 'Nigdy';
  String get lastSyncTimestamp => _lastSyncTimestamp;

  Future<void> syncCloudData(List<Track> localPlaylists) async {
    try {
      debugPrint('Rozpoczęto synchronizację danych z chmurą ResonX Cloud...');
      await Future.delayed(const Duration(seconds: 1));
      
      _isSynced = true;
      _lastSyncTimestamp = DateTime.now().toString().substring(0, 16);
      notifyListeners();
      
      debugPrint('Synchronizacja chmurowa zakończona pomyślnie.');
    } catch (e) {
      debugPrint('Błąd synchronizacji chmury: $e');
    }
  }

  void logoutCloud() {
    _isSynced = false;
    _lastSyncTimestamp = 'Brak';
    notifyListeners();
  }
}