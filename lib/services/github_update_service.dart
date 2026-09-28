import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GithubUpdateService extends ChangeNotifier {
  static final GithubUpdateService instance = GithubUpdateService._internal();
  GithubUpdateService._internal();

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  String _currentVersion = '2.4.0';
  String get currentVersion => _currentVersion;

  String _latestVersion = '';
  String get latestVersion => _latestVersion;

  String _downloadUrl = '';
  String _releaseNotes = '';
  String get releaseNotes => _releaseNotes;

  bool _updateAvailable = false;
  bool get updateAvailable => _updateAvailable;

  // Inicjalizacja i sprawdzenie wersji przy starcie
  Future<void> init() async {
    try {
      _currentVersion = '2.4.0'; // Domyślna wersja produkcyjna ResonX
    } catch (e) {
      debugPrint('[GithubUpdate] Błąd inicjalizacji wersji: $e');
    }
  }

  // Sprawdzanie aktualizacji z GitHub API
  Future<bool> checkForUpdates({bool showNoUpdateDialog = false, BuildContext? context}) async {
    _isChecking = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://api.github.com/repos/Piter2020ja/ResonX/releases/latest');
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagName = data['tag_name'] as String? ?? 'v2.4.0';
        _releaseNotes = data['body'] as String? ?? 'Brak opisu zmian dla tej wersji.';
        
        // Czyszczenie tagu z litery 'v' (np. v2.5.0 -> 2.5.0)
        _latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

        // Szukanie odpowiedniego pliku w assets (APK dla Androida lub ZIP dla Windowsa)
        final assets = data['assets'] as List<dynamic>? ?? [];
        _downloadUrl = '';

        for (var asset in assets) {
          final name = asset['name'].toString().toLowerCase();
          if (Platform.isAndroid && name.endsWith('.apk')) {
            _downloadUrl = asset['browser_download_url'];
            break;
          } else if (Platform.isWindows && (name.endsWith('.zip') || name.endsWith('.exe'))) {
            _downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        // Jeśli nie znaleziono assetu, bierzemy domyślny link do release
        if (_downloadUrl.isEmpty) {
          _downloadUrl = data['html_url'] ?? 'https://github.com/Piter2020ja/ResonX/releases';
        }

        _updateAvailable = _isVersionNewer(_latestVersion, _currentVersion);
        debugPrint('[GithubUpdate] Obecna wersja: $_currentVersion, Najnowsza na GitHub: $_latestVersion, Dostępna: $_updateAvailable');

        _isChecking = false;
        notifyListeners();

        if (_updateAvailable && context != null && context.mounted) {
          _showUpdateDialog(context);
        } else if (!_updateAvailable && showNoUpdateDialog && context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ResonX jest w najnowszej wersji!')),
          );
        }

        return _updateAvailable;
      }
    } catch (e) {
      debugPrint('[GithubUpdate] Błąd sieciowy podczas sprawdzania aktualizacji: $e');
    }

    _isChecking = false;
    notifyListeners();
    return false;
  }

  // Porównywanie wersji (np. 2.5.0 > 2.4.0)
  bool _isVersionNewer(String latest, String current) {
    try {
      List<int> lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int l = i < lParts.length ? lParts[i] : 0;
        int c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  // Wyświetlanie okna aktualizacji w aplikacji
  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          'Dostępna nowa wersja v$_latestVersion!',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masz obecnie wersję v$_currentVersion. Pobierz aktualizację, aby zyskać nowe funkcje i poprawki błędów.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Co nowego:',
                style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _releaseNotes,
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Później', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () {
              Navigator.pop(ctx);
              executeDownloadAndInstall(context);
            },
            child: const Text('Pobierz i aktualizuj', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Pobieranie i uruchamianie instalacji
  Future<void> executeDownloadAndInstall(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rozpoczęto pobieranie aktualizacji ResonX...')),
      );

      if (Platform.isAndroid) {
        // Pobieranie pliku APK do folderu tymczasowego
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/ResonX-v$_latestVersion.apk';
        
        final response = await http.get(Uri.parse(_downloadUrl));
        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          // Otwarcie pliku / wywołanie instalatora systemowego
          final uri = Uri.file(filePath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(Uri.parse(_downloadUrl), mode: LaunchMode.externalApplication);
          }
        }
      } else {
        // Na Windowsie otwórz przeglądarkę bezpośrednio pod adresem instalatora/zipa
        final uri = Uri.parse(_downloadUrl.isNotEmpty ? _downloadUrl : 'https://github.com/Piter2020ja/ResonX/releases');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[GithubUpdate] Błąd instalacji aktualizacji: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania: $e', style: const TextStyle(color: Colors.white))),
        );
      }
    }
  }
}