import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String get downloadUrl => _downloadUrl;

  String _releaseNotes = '';
  String get releaseNotes => _releaseNotes;

  bool _updateAvailable = false;
  bool get updateAvailable => _updateAvailable;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  // Inicjalizacja i dynamiczne sprawdzenie zainstalowanej wersji z systemu
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _currentVersion = info.version;
      } else {
        _currentVersion = '2.4.0';
      }
      debugPrint('[GithubUpdate] Zainicjalizowano wersję ResonX: $_currentVersion');
    } catch (e) {
      _currentVersion = '2.4.0'; // Domyślna wersja zapasowa
      debugPrint('[GithubUpdate] Błąd inicjalizacji wersji z systemu, użyto domyślnej: $e');
    }
    notifyListeners();
  }

  // Sprawdzanie aktualizacji z GitHub API
  Future<bool> checkForUpdates({bool showNoUpdateDialog = false, BuildContext? context}) async {
    _isChecking = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://api.github.com/repos/Piter2020ja/ResonX/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ResonX-Updater-Client',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagName = data['tag_name'] as String? ?? 'v2.4.0';
        _releaseNotes = data['body'] as String? ?? 'Brak opisu zmian dla tej wersji.';

        // Czyszczenie tagu z litery 'v' (np. v2.5.0 -> 2.5.0)
        _latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

        // Szukanie dedykowanego pliku dla konkretnej platformy (APK dla Androida, IPA dla iOS, ZIP/EXE dla Windowsa)
        final assets = data['assets'] as List<dynamic>? ?? [];
        _downloadUrl = '';

        for (var asset in assets) {
          final name = asset['name'].toString().toLowerCase();
          final downloadUrl = asset['browser_download_url'] as String? ?? '';

          if (Platform.isAndroid && name.endsWith('.apk')) {
            _downloadUrl = downloadUrl;
            break;
          } else if (Platform.isIOS && name.endsWith('.ipa')) {
            _downloadUrl = downloadUrl;
            break;
          } else if (Platform.isWindows && (name.endsWith('.zip') || name.endsWith('.exe'))) {
            _downloadUrl = downloadUrl;
            break;
          }
        }

        // Jeśli nie znaleziono bezpośredniego pliku instalacyjnego, linkujemy do strony wydania na GitHubie
        if (_downloadUrl.isEmpty) {
          _downloadUrl = data['html_url'] ?? 'https://github.com/Piter2020ja/ResonX/releases';
        }

        _updateAvailable = _isVersionNewer(_latestVersion, _currentVersion);
        debugPrint('[GithubUpdate] Obecna wersja: $_currentVersion, Najnowsza na GitHub: $_latestVersion, Dostępna: $_updateAvailable, URL: $_downloadUrl');

        _isChecking = false;
        notifyListeners();

        if (_updateAvailable && context != null && context.mounted) {
          _showUpdateDialog(context);
        } else if (!_updateAvailable && showNoUpdateDialog && context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF161822),
              content: Text(
                'ResonX jest w najnowszej wersji!',
                style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold),
              ),
            ),
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

  // Porównywanie wersji semantycznych (np. 2.4.1 > 2.4.0)
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
        backgroundColor: const Color(0xFF10121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00F2FE), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Color(0xFF00F2FE), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dostępna wersja v$_latestVersion!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aktualna wersja: v$_currentVersion. Zainstaluj aktualizację, aby zachować pełną stabilność i otrzymać nowe funkcje.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'Co nowego w tej wersji:',
                style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _releaseNotes,
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F2FE),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              executeDownloadAndInstall(context);
            },
            child: const Text('Pobierz i aktualizuj', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Pobieranie i uruchamianie instalacji (Android, iOS, Windows)
  Future<void> executeDownloadAndInstall(BuildContext context) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _isDownloading = true;
        _downloadProgress = 0.0;
        notifyListeners();

        // Okienko dialogowe z postępem pobierania
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF10121A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  Platform.isAndroid ? 'Pobieranie paczki APK...' : 'Pobieranie paczki IPA...',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        final extension = Platform.isAndroid ? 'apk' : 'ipa';
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/ResonX-v$_latestVersion.$extension';

        final client = http.Client();
        final request = http.Request('GET', Uri.parse(_downloadUrl));
        final streamedResponse = await client.send(request);

        final totalBytes = streamedResponse.contentLength ?? 0;
        int receivedBytes = 0;
        List<int> bytes = [];

        await for (var chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress = receivedBytes / totalBytes;
            notifyListeners();
          }
        }

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        _isDownloading = false;
        notifyListeners();

        // Zamknięcie okienka postępu
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Uruchomienie pliku lub otwarcie w przeglądarce
        final fileUri = Uri.file(filePath);
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(Uri.parse(_downloadUrl), mode: LaunchMode.externalApplication);
        }
      } else {
        // Na Windowsie otwórz przeglądarkę pod bezpośrednim adresem wydania/instalatora
        final uri = Uri.parse(_downloadUrl.isNotEmpty ? _downloadUrl : 'https://github.com/Piter2020ja/ResonX/releases');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _isDownloading = false;
      notifyListeners();

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('[GithubUpdate] Błąd instalacji aktualizacji: $e');

      // Bezpieczny fallback – bezpośrednie przejście do GitHuba
      final fallbackUri = Uri.parse(_downloadUrl.isNotEmpty ? _downloadUrl : 'https://github.com/Piter2020ja/ResonX/releases');
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }
}