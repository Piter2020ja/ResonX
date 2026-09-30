import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'core/theme.dart';
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
import 'services/github_update_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/resonx_welcome_setup_dialog.dart';
import 'ui/widgets/floating_mini_player_window.dart';

// Globalny kontroler rozgłoszeniowy zapobiegający błędowi "Stream has already been listened to"
Stream<dynamic>? _broadcastOverlayStream;
Stream<dynamic> get _safeOverlayStream {
  _broadcastOverlayStream ??= FlutterOverlayWindow.overlayListener.asBroadcastStream();
  return _broadcastOverlayStream!;
}

// =============================================================================
// SYSTEMOWY PUNKT WEJŚCIA DLA PŁYWAJĄCEJ WYSPY NAD APLIKACJAMI (ANDROID OVERLAY)
// =============================================================================
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TrueSystemOverlayIsland(),
    ),
  );
}

class TrueSystemOverlayIsland extends StatefulWidget {
  const TrueSystemOverlayIsland({super.key});

  @override
  State<TrueSystemOverlayIsland> createState() => _TrueSystemOverlayIslandState();
}

class _TrueSystemOverlayIslandState extends State<TrueSystemOverlayIsland>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _trackData = {
    'title': 'ResonX Music',
    'artist': 'Odtwarzacz w tle',
    'coverUrl': '',
    'isPlaying': false,
    'position': 0,
    'duration': 180,
  };
  bool _isExpanded = false;
  late AnimationController _waveAnimController;
  Timer? _positionTicker;
  StreamSubscription? _overlaySub;

  // Kontrola przeciągania paska bez zrywania dźwięku
  bool _isDraggingProgress = false;
  double _dragFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    try {
      _overlaySub = _safeOverlayStream.listen((dynamic event) {
        if (!mounted || event == null) return;
        try {
          Map<String, dynamic> parsed;
          if (event is String) {
            parsed = jsonDecode(event) as Map<String, dynamic>;
          } else if (event is Map) {
            parsed = Map<String, dynamic>.from(event);
          } else {
            return;
          }
          if (!_isDraggingProgress) {
            setState(() {
              _trackData = parsed;
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[ResonX Overlay] Błąd inicjalizacji nasłuchu: $e');
    }

    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isDraggingProgress) return;
      final bool isPlaying = _trackData['isPlaying'] as bool? ?? false;
      if (isPlaying) {
        final int currentPos = _trackData['position'] as int? ?? 0;
        final int totalDur = _trackData['duration'] as int? ?? 180;
        if (currentPos < totalDur) {
          setState(() {
            _trackData['position'] = currentPos + 1;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    _positionTicker?.cancel();
    _waveAnimController.dispose();
    super.dispose();
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _sendAction(String action) {
    FlutterOverlayWindow.shareData(action);
  }

  void _sendSeek(int targetSeconds) {
    FlutterOverlayWindow.shareData('ACTION_SEEK:$targetSeconds');
  }

  @override
  Widget build(BuildContext context) {
    final title = _trackData['title'] as String? ?? 'ResonX Music';
    final artist = _trackData['artist'] as String? ?? 'Odtwarzacz w tle';
    final coverUrl = _trackData['coverUrl'] as String? ?? '';
    final isPlaying = _trackData['isPlaying'] as bool? ?? false;
    final int positionSec = _trackData['position'] as int? ?? 0;
    final int durationSec = (_trackData['duration'] as int? ?? 180) > 0 ? (_trackData['duration'] as int? ?? 180) : 180;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          width: _isExpanded ? 345 : 210,
          padding: EdgeInsets.symmetric(
            horizontal: _isExpanded ? 12 : 8,
            vertical: _isExpanded ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF090A0F).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(_isExpanded ? 20 : 26),
            border: Border.all(
              color: const Color(0xFF00E599).withValues(alpha: _isExpanded ? 0.75 : 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 18,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: const Color(0xFF00E599).withValues(alpha: isPlaying ? 0.22 : 0.05),
                blurRadius: 12,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_isExpanded ? 18 : 22),
            child: _isExpanded
                ? _buildExpandedContent(title, artist, coverUrl, isPlaying, positionSec, durationSec)
                : _buildCollapsedContent(title, coverUrl, isPlaying),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(String title, String coverUrl, bool isPlaying) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isExpanded = true;
                });
                FlutterOverlayWindow.resizeOverlay(355, 175, true);
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: coverUrl.isNotEmpty && coverUrl.startsWith('http')
                        ? Image.network(
                            coverUrl,
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[900],
                              width: 30,
                              height: 30,
                              child: const Icon(Icons.music_note, color: Color(0xFF00E599), size: 16),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.music_note, color: Color(0xFF00E599), size: 16),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        _buildMiniWaveform(isPlaying),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _trackData['isPlaying'] = !isPlaying;
              });
              _sendAction('ACTION_TOGGLE');
            },
            child: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: const Color(0xFF00E599),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    String title,
    String artist,
    String coverUrl,
    bool isPlaying,
    int positionSec,
    int durationSec,
  ) {
    // Obliczanie ułamka postępu z uwzględnieniem aktywnego przeciągania palcem
    final double currentFraction = _isDraggingProgress
        ? _dragFraction
        : (positionSec / durationSec).clamp(0.0, 1.0);
    final int displayedPositionSec = _isDraggingProgress
        ? (_dragFraction * durationSec).toInt()
        : positionSec;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = false;
                });
                FlutterOverlayWindow.resizeOverlay(215, 48, true);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl.isNotEmpty && coverUrl.startsWith('http')
                    ? Image.network(
                        coverUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey[900],
                          child: const Icon(Icons.music_note, color: Color(0xFF00E599)),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[900],
                        child: const Icon(Icons.music_note, color: Color(0xFF00E599)),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isExpanded = false;
                  });
                  FlutterOverlayWindow.resizeOverlay(215, 48, true);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF00E599), size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Zwiń wyspę',
              onPressed: () {
                setState(() {
                  _isExpanded = false;
                });
                FlutterOverlayWindow.resizeOverlay(215, 48, true);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Zamknij nakładkę',
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // STABILNY, BEZPIECZNY PASEK POSTĘPU Z OBSŁUGĄ GESTU BEZ ZAWIESZANIA DŹWIĘKU
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Text(
                _formatDuration(displayedPositionSec),
                style: const TextStyle(color: Colors.white54, fontSize: 9.5),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double barWidth = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDraggingProgress = true;
                          _dragFraction = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _dragFraction = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        final targetSec = (_dragFraction * durationSec).toInt();
                        setState(() {
                          _trackData['position'] = targetSec;
                          _isDraggingProgress = false;
                        });
                        // Wysyłamy przewijanie tylko RAZ po zakończeniu gestu przeciągnięcia
                        _sendSeek(targetSec);
                      },
                      onTapUp: (details) {
                        final frac = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                        final targetSec = (frac * durationSec).toInt();
                        setState(() {
                          _trackData['position'] = targetSec;
                        });
                        _sendSeek(targetSec);
                      },
                      child: Container(
                        height: 18,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: currentFraction,
                              child: Container(
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E599),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E599).withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(
                _formatDuration(durationSec),
                style: const TextStyle(color: Colors.white54, fontSize: 9.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _sendAction('ACTION_PREV');
              },
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _trackData['isPlaying'] = !isPlaying;
                });
                _sendAction('ACTION_TOGGLE');
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E599),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _sendAction('ACTION_NEXT');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniWaveform(bool isPlaying) {
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, child) {
        return Row(
          children: List.generate(8, (index) {
            double height = 2.0;
            if (isPlaying) {
              final wave = math.sin((_waveAnimController.value * 2 * math.pi) + (index * 0.7));
              height = 2.0 + (wave.abs() * 5.0);
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.8),
              width: 1.8,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF00E599).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(1.0),
              ),
            );
          }),
        );
      },
    );
  }
}

// =============================================================================
// GLOBALNY SERWIS OSZCZĘDZANIA BATERII
// =============================================================================
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

Future<void> _configureAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

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

    debugPrint('[ResonX AudioSession] Sesja audio skonfigurowana.');
  } catch (e) {
    debugPrint('[ResonX AudioSession] Błąd sesji: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF08090C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  if (Platform.isAndroid || Platform.isIOS) {
    await _configureAudioSession();
    await AudioPlayerService.instance.initAudioService();
  }

  await AuthCloudService.instance.init();

  ErrorWidget.builder = (FlutterErrorDetails details) => const SizedBox.shrink();
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionStr = details.exceptionAsString();
    if (exceptionStr.contains('overflowed') ||
        exceptionStr.contains('RenderFlex') ||
        exceptionStr.contains('No Overlay widget found') ||
        exceptionStr.contains('Bad state: Stream has already been listened to') ||
        exceptionStr.contains('ListTile background color or ink splashes may be invisible')) {
      return;
    }
    FlutterError.presentError(details);
  };

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      GlobalHotkeysService.instance.initHotkeys();
      DiscordRpcService.instance.initialize();
    } catch (e) {
      debugPrint('[ResonX Desktop] Błąd inicjalizacji: $e');
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
        ChangeNotifierProvider.value(value: GithubUpdateService.instance),
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
      theme: ResonXTheme.darkTheme,
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const FloatingMiniPlayerWindow(),
                ],
              ),
            ),
          ],
        );
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
      _checkAndTriggerWelcomeSetup();
    });
  }

  Future<void> _checkAndTriggerWelcomeSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isCompleted = prefs.getBool('resonx_setup_completed_v4') ?? false;

      // Wyświetla konfigurację TYLKO wtedy, gdy użytkownik jeszcze jej nie ukończył
      if (!isCompleted && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.75),
          builder: (dialogContext) => const ResonXWelcomeSetupDialog(),
        );
      }
    } catch (e) {
      debugPrint('[ResonX Setup Gate] Błąd sprawdzania SharedPreferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}