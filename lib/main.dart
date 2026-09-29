import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';

import 'services/audio_player_service.dart';
import 'services/dsp_audio_engine.dart';
import 'services/stats_and_achievements_service.dart';
import 'services/auth_cloud_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/listening_history_service.dart';
import 'services/explicit_filter_service.dart';
import 'services/playlist_manager_service.dart';
import 'services/downloader_service.dart';
import 'services/lyrics_service.dart';
import 'services/local_scanner_service.dart';
import 'services/playlist_service.dart';
import 'services/dsp_processor_service.dart';
import 'services/equalizer_service.dart';
import 'services/dj_mode_service.dart';
import 'services/global_hotkeys_service.dart';
import 'services/discord_rpc_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/resonx_welcome_setup_dialog.dart';

// --- GLOBALNY SERWIS OSZCZĘDZANIA BATERII (BATTERY SAVER / LOW POWER UI) ---
class BatterySaverService extends ChangeNotifier {
  static final BatterySaverService instance = BatterySaverService._internal();
  BatterySaverService._internal();

  bool _isBatterySaverEnabled = false;
  bool get isBatterySaverEnabled => _isBatterySaverEnabled;

  void setBatterySaver(bool enabled) {
    if (_isBatterySaverEnabled != enabled) {
      _isBatterySaverEnabled = enabled;
      debugPrint('[ResonX BatterySaver] Tryb Low Power UI: $enabled');
      notifyListeners();
    }
  }

  void toggle() {
    setBatterySaver(!_isBatterySaverEnabled);
  }
}

/// Inicjalizacja konfiguracji sesji audio dla urządzeń mobilnych (iOS oraz Android)
Future<void> _configureAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Obsługa zdarzeń przerwania odtwarzania (np. połączenie przychodzące na iOS/Android)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            AudioPlayerService.instance.setVolume(AudioPlayerService.instance.volume * 0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            AudioPlayerService.instance.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            AudioPlayerService.instance.setVolume(AudioPlayerService.instance.volume);
            break;
          case AudioInterruptionType.pause:
            AudioPlayerService.instance.resume();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    debugPrint('[ResonX AudioSession] Natywna sesja audio została skonfigurowana pomyślnie.');
  } catch (e) {
    debugPrint('[ResonX AudioSession] Błąd konfiguracji sesji audio: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Konfiguracja przezroczystego paska stanu dla urządzeń mobilnych
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF08090C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicjalizacja sesji audio dla mobilnego odtwarzania w tle
  if (Platform.isIOS || Platform.isAndroid) {
    await _configureAudioSession();
  }

  // Wczytanie zapisanej sesji użytkownika z pamięci
  await AuthCloudService.instance.init();

  // Całkowite wyłączenie rysowania pasków overflow na ekranie
  ErrorWidget.builder = (FlutterErrorDetails details) => const SizedBox.shrink();
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionStr = details.exceptionAsString();
    if (exceptionStr.contains('overflowed') || exceptionStr.contains('RenderFlex')) {
      return;
    }
    FlutterError.presentError(details);
  };

  // Obsługa SQLite FFI dla komputerów z systemem Windows i Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicjalizacja serwisów desktopowych wyłącznie na komputerach
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      GlobalHotkeysService.instance.initHotkeys();
      DiscordRpcService.instance.initialize();
    } catch (e) {
      debugPrint('[ResonX Desktop] Błąd inicjalizacji rozszerzeń desktopowych: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AudioPlayerService.instance),
        ChangeNotifierProvider.value(value: DspAudioEngine.instance),
        ChangeNotifierProvider.value(value: StatsAndAchievementsService.instance),
        ChangeNotifierProvider.value(value: AuthCloudService.instance),
        ChangeNotifierProvider.value(value: CloudSyncService.instance),
        ChangeNotifierProvider.value(value: ListeningHistoryService.instance),
        ChangeNotifierProvider.value(value: ExplicitFilterService.instance),
        ChangeNotifierProvider.value(value: PlaylistManagerService.instance),
        ChangeNotifierProvider.value(value: DownloaderService.instance),
        ChangeNotifierProvider.value(value: LyricsService.instance),
        Provider<LocalScannerService>.value(value: LocalScannerService.instance),
        ChangeNotifierProvider.value(value: PlaylistService.instance),
        ChangeNotifierProvider.value(value: DspProcessorService.instance),
        ChangeNotifierProvider.value(value: EqualizerService.instance),
        ChangeNotifierProvider.value(value: DjModeService.instance),
        ChangeNotifierProvider.value(value: BatterySaverService.instance),
      ],
      child: const ResonXApp(),
    ),
  );
}

class ResonXApp extends StatelessWidget {
  const ResonXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResonX Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF08090C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F2FE),
          secondary: Color(0xFF9B51E0),
          surface: Color(0xFF12141D),
        ),
      ),
      builder: (context, child) {
        // Zwraca natywny widok na cały ekran bez sztucznego obcinania szerokości
        return child ?? const SizedBox.shrink();
      },
      home: const AppRootLauncher(),
    );
  }
}

class AppRootLauncher extends StatefulWidget {
  const AppRootLauncher({super.key});

  @override
  State<AppRootLauncher> createState() => _AppRootLauncherState();
}

class _AppRootLauncherState extends State<AppRootLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerWelcomeSetup();
    });
  }

  void _triggerWelcomeSetup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => const ResonXWelcomeSetupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}