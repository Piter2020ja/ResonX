import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/audio_player_service.dart';
import '../../services/lyrics_service.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late AnimationController _spectrumAnimController;
  late AnimationController _glowAnimController;
  late AnimationController _queueSlideController;
  late Animation<double> _glowAnimation;

  bool _isQueueExpanded = false;
  bool _showLyricsOverlay = false;
  bool _isMuted = false;
  double _volumeBeforeMute = 1.0;
  final List<double> _fftMagnitudes = List.generate(32, (index) => 0.1);
  Timer? _fftDecayTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _spectrumAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _glowAnimController, curve: Curves.easeInOut),
    );

    _queueSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startFftSimulation();
  }

  void _startFftSimulation() {
    _fftDecayTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) return;
      final player = Provider.of<AudioPlayerService>(context, listen: false);
      if (player.isPlaying) {
        setState(() {
          for (int i = 0; i < _fftMagnitudes.length; i++) {
            final bias = i < 8 ? 0.7 : (i < 20 ? 0.5 : 0.3);
            final target = (_random.nextDouble() * bias) + 0.15;
            _fftMagnitudes[i] = _fftMagnitudes[i] * 0.4 + target * 0.6;
          }
        });
      } else {
        setState(() {
          for (int i = 0; i < _fftMagnitudes.length; i++) {
            _fftMagnitudes[i] = max(0.05, _fftMagnitudes[i] * 0.85);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fftDecayTimer?.cancel();
    _spectrumAnimController.dispose();
    _glowAnimController.dispose();
    _queueSlideController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleQueue() {
    setState(() {
      _isQueueExpanded = !_isQueueExpanded;
      if (_isQueueExpanded) {
        _queueSlideController.forward();
      } else {
        _queueSlideController.reverse();
      }
    });
  }

  void _toggleMute(AudioPlayerService player) {
    if (_isMuted) {
      player.setVolume(_volumeBeforeMute);
      setState(() => _isMuted = false);
    } else {
      _volumeBeforeMute = player.volume;
      player.setVolume(0.0);
      setState(() => _isMuted = true);
    }
  }

  void _showSleepTimerDialog(BuildContext context, AudioPlayerService player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ResonXColors.surfaceBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bedtime, color: ResonXColors.neonCyan),
            SizedBox(width: 10),
            Text('Sleep Timer (Wyłącznik czasowy)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.hasActiveSleepTimer) ...[
              Text(
                'Aktywny timer: ${player.remainingSleepSeconds ~/ 60} min ${player.remainingSleepSeconds % 60} s',
                style: const TextStyle(color: ResonXColors.cyberJade, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ResonXColors.errorRed),
                onPressed: () {
                  player.cancelSleepTimer();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Anuluj Timer', style: TextStyle(color: Colors.white)),
              ),
              const Divider(color: ResonXColors.cardBorder, height: 24),
            ],
            ListTile(
              title: const Text('15 minut', style: TextStyle(color: ResonXColors.textPrimary)),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 15));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('30 minut', style: TextStyle(color: ResonXColors.textPrimary)),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 30));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('45 minut', style: TextStyle(color: ResonXColors.textPrimary)),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 45));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('60 minut (1 godzina)', style: TextStyle(color: ResonXColors.textPrimary)),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 60));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaybackSpeedDialog(BuildContext context, AudioPlayerService player) {
    double tempSpeed = player.speed;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ResonXColors.surfaceBlack,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.speed, color: ResonXColors.cyberJade),
              SizedBox(width: 10),
              Text('Prędkość & Pitch DSP', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Slider(
                value: tempSpeed,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                activeColor: ResonXColors.cyberJade,
                inactiveColor: ResonXColors.deepGraphite,
                onChanged: (val) {
                  setDialogState(() => tempSpeed = val);
                  player.setPlaybackSpeed(val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() => tempSpeed = 0.8);
                      player.setPlaybackSpeed(0.8);
                    },
                    child: const Text('0.8x (Slowed)', style: TextStyle(color: ResonXColors.neonCyan)),
                  ),
                  TextButton(
                    onPressed: () {
                      setDialogState(() => tempSpeed = 1.0);
                      player.setPlaybackSpeed(1.0);
                    },
                    child: const Text('1.0x (Standard)', style: TextStyle(color: ResonXColors.cyberJade)),
                  ),
                  TextButton(
                    onPressed: () {
                      setDialogState(() => tempSpeed = 1.25);
                      player.setPlaybackSpeed(1.25);
                    },
                    child: const Text('1.25x (Speed Up)', style: TextStyle(color: ResonXColors.neonCyan)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Zamknij', style: TextStyle(color: ResonXColors.textSecondary)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<AudioPlayerService>(context);
    final lyricsService = Provider.of<LyricsService>(context);
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final maxDur = player.duration.inMilliseconds.toDouble();
    final curPos = player.position.inMilliseconds.toDouble().clamp(0.0, max(maxDur, 1.0)).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isQueueExpanded) _buildQuickQueueDrawer(player),
        if (_showLyricsOverlay) _buildLiveLyricsHud(lyricsService, player),
        Container(
          height: 104,
          decoration: BoxDecoration(
            color: ResonXColors.surfaceBlack.withOpacity(0.96),
            border: const Border(
              top: BorderSide(color: ResonXColors.cardBorder, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: ResonXColors.cyberJade.withOpacity(player.isPlaying ? 0.12 : 0.02),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 5,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                    activeTrackColor: ResonXColors.cyberJade,
                    inactiveTrackColor: ResonXColors.deepGraphite,
                  ),
                  child: Slider(
                    value: curPos,
                    min: 0.0,
                    max: max(maxDur, 1.0),
                    onChanged: (val) {
                      player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  // POPRAWIONE: Usunięto niedefiniowany parametr track: track
                                  pageBuilder: (_, __, ___) => const PlayerScreen(),
                                  transitionsBuilder: (_, animation, __, child) =>
                                      FadeTransition(opacity: animation, child: child),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: ResonXColors.cyberJade.withOpacity(
                                      player.isPlaying ? _glowAnimation.value * 0.45 : 0.05,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  track.coverUrl,
                                  width: 62,
                                  height: 62,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 62,
                                    height: 62,
                                    color: ResonXColors.deepGraphite,
                                    child: const Icon(Icons.music_note, color: ResonXColors.cyberJade),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              // POPRAWIONE: Usunięto niedefiniowany parametr track: track
                              MaterialPageRoute(builder: (_) => const PlayerScreen()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ResonXColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: ResonXColors.deepGraphite,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: ResonXColors.cardBorder),
                                    ),
                                    child: Text(
                                      track.fileFormat,
                                      style: const TextStyle(
                                        color: ResonXColors.cyberJade,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                                    style: const TextStyle(color: ResonXColors.neonCyan, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildFull32BandSpectrum(),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: player.isShuffleMode ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Smart Shuffle (Unikanie powtórek wykonawcy)',
                            onPressed: player.toggleShuffle,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: ResonXColors.textPrimary, size: 28),
                            tooltip: 'Poprzedni utwór (Klawisz: Strzałka w lewo)',
                            onPressed: player.playPreviousTrack,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [ResonXColors.cyberJade, ResonXColors.neonCyan],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ResonXColors.cyberJade.withOpacity(0.5),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 28,
                              ),
                              tooltip: player.isPlaying ? 'Wstrzymaj (Spacja)' : 'Wznów odtwarzanie (Spacja)',
                              onPressed: player.togglePlayPause,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: ResonXColors.textPrimary, size: 28),
                            tooltip: 'Następny utwór (Klawisz: Strzałka w prawo)',
                            onPressed: player.playNextTrack,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.repeat,
                              color: player.isLoopMode ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Pętla utworu / odtwarzania',
                            onPressed: player.toggleLoop,
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.subtitles,
                              color: _showLyricsOverlay ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Pływające teksty na żywo (LRCLIB Sync)',
                            onPressed: () {
                              setState(() => _showLyricsOverlay = !_showLyricsOverlay);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.speed, color: ResonXColors.textSecondary, size: 20),
                            tooltip: 'Regulator Pitch & Prędkości (0.5x - 2.0x)',
                            onPressed: () => _showPlaybackSpeedDialog(context, player),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.bedtime,
                              color: player.hasActiveSleepTimer ? ResonXColors.neonCyan : ResonXColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Sleep Timer (Wyłącznik czasowy)',
                            onPressed: () => _showSleepTimerDialog(context, player),
                          ),
                          IconButton(
                            icon: Icon(
                              _isMuted || player.volume == 0
                                  ? Icons.volume_off
                                  : (player.volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                              color: _isMuted ? ResonXColors.errorRed : ResonXColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: _isMuted ? 'Wyłącz wyciszenie' : 'Wycisz (Mute)',
                            onPressed: () => _toggleMute(player),
                          ),
                          SizedBox(
                            width: 88,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                activeTrackColor: ResonXColors.neonCyan,
                                inactiveTrackColor: ResonXColors.deepGraphite,
                                thumbColor: ResonXColors.neonCyan,
                              ),
                              child: Slider(
                                value: player.volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  if (_isMuted) setState(() => _isMuted = false);
                                  player.setVolume(val);
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              track.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: track.isFavorite ? Colors.redAccent : ResonXColors.textSecondary,
                              size: 22,
                            ),
                            tooltip: 'Ulubione',
                            onPressed: () => player.toggleFavorite(track),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.queue_music,
                              color: _isQueueExpanded ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                              size: 22,
                            ),
                            tooltip: 'Podgląd kolejki odtwarzania',
                            onPressed: _toggleQueue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFull32BandSpectrum() {
    return SizedBox(
      height: 12,
      child: Row(
        children: List.generate(32, (index) {
          final mag = _fftMagnitudes[index];
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.8),
              height: max(2.0, mag * 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    ResonXColors.cyberJade,
                    index > 22 ? Colors.amberAccent : ResonXColors.neonCyan,
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLiveLyricsHud(LyricsService lyricsService, AudioPlayerService player) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: ResonXColors.deepGraphite.withOpacity(0.92),
        border: const Border(top: BorderSide(color: ResonXColors.cyberJade, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: ResonXColors.cyberJade, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lyricsService.getLiveLine(player.position) ?? 'Wyszukiwanie tekstu LRCLIB w toku...',
              style: const TextStyle(
                color: ResonXColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: ResonXColors.textSecondary, size: 18),
            onPressed: () => setState(() => _showLyricsOverlay = false),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQueueDrawer(AudioPlayerService player) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ResonXColors.deepGraphite,
        border: Border(
          top: BorderSide(color: ResonXColors.cardBorder, width: 1.5),
          bottom: BorderSide(color: ResonXColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: ResonXColors.surfaceBlack,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue_music, color: ResonXColors.cyberJade, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'KOLEJKA ODTWARZANIA (${player.queue.length})',
                      style: const TextStyle(
                        color: ResonXColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _toggleQueue,
                  child: const Text('Zwiń', style: TextStyle(color: ResonXColors.neonCyan)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: player.queue.length,
              itemBuilder: (context, index) {
                final item = player.queue[index];
                final isCurrent = index == player.currentIndex;

                return ListTile(
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item.coverUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        color: ResonXColors.surfaceBlack,
                        child: const Icon(Icons.music_note, color: ResonXColors.cyberJade, size: 16),
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? ResonXColors.cyberJade : ResonXColors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    item.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 11),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.volume_up, color: ResonXColors.cyberJade, size: 18)
                      : null,
                  onTap: () {
                    player.playTrack(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}