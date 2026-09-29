import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/audio_player_service.dart';
import '../../services/lyrics_service.dart';
import '../../main.dart';
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
  double _volumeBeforeMute = 0.5;
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
      final battery = Provider.of<BatterySaverService>(context, listen: false);

      if (battery.isBatterySaverEnabled) {
        return;
      }

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
      player.setVolume(_volumeBeforeMute <= 0.0 ? 0.5 : _volumeBeforeMute);
      setState(() => _isMuted = false);
    } else {
      _volumeBeforeMute = player.volume <= 0.0 ? 0.5 : player.volume;
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
        content: Material(
          color: Colors.transparent,
          child: Column(
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
                tileColor: Colors.transparent,
                title: const Text('15 minut', style: TextStyle(color: ResonXColors.textPrimary)),
                onTap: () {
                  player.setSleepTimer(const Duration(minutes: 15));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                title: const Text('30 minut', style: TextStyle(color: ResonXColors.textPrimary)),
                onTap: () {
                  player.setSleepTimer(const Duration(minutes: 30));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                title: const Text('45 minut', style: TextStyle(color: ResonXColors.textPrimary)),
                onTap: () {
                  player.setSleepTimer(const Duration(minutes: 45));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                title: const Text('60 minut (1 godzina)', style: TextStyle(color: ResonXColors.textPrimary)),
                onTap: () {
                  player.setSleepTimer(const Duration(minutes: 60));
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
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
          content: Material(
            color: Colors.transparent,
            child: Column(
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

  void _showMobileMoreControlsSheet(BuildContext context, AudioPlayerService player) {
    final track = player.currentTrack;
    if (track == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: ResonXColors.surfaceBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ResonXColors.cardBorder, width: 1.2),
      ),
      builder: (ctx) {
        return Consumer<AudioPlayerService>(
          builder: (context, livePlayer, child) {
            final double currentVol = (livePlayer.volume > 0.0 ? livePlayer.volume : 0.5).clamp(0.0, 1.0);
            final int displayPercent = (currentVol * 100).round();

            return SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: ResonXColors.cyberJade, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Zaawansowane Kontrolki Audio',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: ResonXColors.textSecondary, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(color: ResonXColors.cardBorder, height: 20),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isMuted || currentVol == 0.0
                                  ? Icons.volume_off
                                  : (currentVol < 0.5 ? Icons.volume_down : Icons.volume_up),
                              color: _isMuted ? ResonXColors.errorRed : ResonXColors.cyberJade,
                              size: 22,
                            ),
                            onPressed: () {
                              _toggleMute(livePlayer);
                            },
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: ResonXColors.cyberJade,
                                inactiveTrackColor: ResonXColors.deepGraphite,
                                thumbColor: ResonXColors.cyberJade,
                              ),
                              child: Slider(
                                value: currentVol,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  if (_isMuted) {
                                    setState(() => _isMuted = false);
                                  }
                                  livePlayer.setVolume(val);
                                },
                              ),
                            ),
                          ),
                          Text(
                            '$displayPercent%',
                            style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: Icon(Icons.subtitles, color: _showLyricsOverlay ? ResonXColors.cyberJade : ResonXColors.textSecondary, size: 18),
                            label: Text(_showLyricsOverlay ? 'Ukryj HUD Tekstu' : 'Pokaż Tekst Live', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              setState(() => _showLyricsOverlay = !_showLyricsOverlay);
                              Navigator.pop(ctx);
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: const Icon(Icons.speed, color: ResonXColors.neonCyan, size: 18),
                            label: Text('Prędkość: ${livePlayer.speed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPlaybackSpeedDialog(context, livePlayer);
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: Icon(Icons.bedtime, color: livePlayer.hasActiveSleepTimer ? ResonXColors.neonCyan : ResonXColors.textSecondary, size: 18),
                            label: Text(livePlayer.hasActiveSleepTimer ? 'Timer: ${livePlayer.remainingSleepSeconds ~/ 60}m' : 'Sleep Timer', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSleepTimerDialog(context, livePlayer);
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: Icon(Icons.queue_music, color: _isQueueExpanded ? ResonXColors.cyberJade : ResonXColors.textSecondary, size: 18),
                            label: Text('Kolejka (${livePlayer.queue.length})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _toggleQueue();
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: Icon(Icons.shuffle, color: livePlayer.isShuffleMode ? ResonXColors.cyberJade : ResonXColors.textSecondary, size: 18),
                            label: Text(livePlayer.isShuffleMode ? 'Shuffle WŁ.' : 'Shuffle WYŁ.', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              livePlayer.toggleShuffle();
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXColors.deepGraphite,
                            avatar: Icon(Icons.repeat, color: livePlayer.isLoopMode ? ResonXColors.cyberJade : ResonXColors.textSecondary, size: 18),
                            label: Text(livePlayer.isLoopMode ? 'Pętla WŁ.' : 'Pętla WYŁ.', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              livePlayer.toggleLoop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
    final bool isTrackFav = player.favoriteTrackIds.contains(track.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 700;

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isQueueExpanded) _buildQuickQueueDrawer(player),
              if (_showLyricsOverlay) _buildLiveLyricsHud(lyricsService, player),
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const PlayerScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  }
                },
                child: Container(
                  height: isMobile ? 88 : 104,
                  decoration: BoxDecoration(
                    color: ResonXColors.surfaceBlack.withValues(alpha: 0.96),
                    border: const Border(
                      top: BorderSide(color: ResonXColors.cardBorder, width: 1.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ResonXColors.cyberJade.withValues(alpha: player.isPlaying ? 0.12 : 0.02),
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
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
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
                                            color: ResonXColors.cyberJade.withValues(
                                              alpha: player.isPlaying ? _glowAnimation.value * 0.45 : 0.05,
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
                                          width: isMobile ? 48 : 62,
                                          height: isMobile ? 48 : 62,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: isMobile ? 48 : 62,
                                            height: isMobile ? 48 : 62,
                                            color: ResonXColors.deepGraphite,
                                            child: const Icon(Icons.music_note, color: ResonXColors.cyberJade),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: isMobile ? 10 : 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
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
                                              style: TextStyle(
                                                color: ResonXColors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: isMobile ? 13 : 14,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              track.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                                            style: const TextStyle(color: ResonXColors.neonCyan, fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _buildFull32BandSpectrum(),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMobile)
                                    IconButton(
                                      icon: Icon(
                                        Icons.shuffle,
                                        color: player.isShuffleMode ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                                        size: 20,
                                      ),
                                      tooltip: 'Smart Shuffle',
                                      onPressed: player.toggleShuffle,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous, color: ResonXColors.textPrimary, size: 26),
                                    tooltip: 'Poprzedni utwór',
                                    onPressed: player.playPreviousTrack,
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [ResonXColors.cyberJade, ResonXColors.neonCyan],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ResonXColors.cyberJade.withValues(alpha: 0.5),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        player.isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.black,
                                        size: isMobile ? 24 : 28,
                                      ),
                                      tooltip: player.isPlaying ? 'Wstrzymaj' : 'Odtwórz',
                                      onPressed: player.togglePlayPause,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next, color: ResonXColors.textPrimary, size: 26),
                                    tooltip: 'Następny utwór',
                                    onPressed: player.playNextTrack,
                                  ),
                                  if (!isMobile)
                                    IconButton(
                                      icon: Icon(
                                        Icons.repeat,
                                        color: player.isLoopMode ? ResonXColors.cyberJade : ResonXColors.textSecondary,
                                        size: 20,
                                      ),
                                      tooltip: 'Pętla utworu',
                                      onPressed: player.toggleLoop,
                                    ),
                                  if (isMobile)
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz_rounded, color: ResonXColors.neonCyan, size: 22),
                                      tooltip: 'Więcej opcji odtwarzacza',
                                      onPressed: () => _showMobileMoreControlsSheet(context, player),
                                    ),
                                ],
                              ),
                              if (!isMobile) ...[
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
                                          value: (player.volume > 0.0 ? player.volume : 0.5).clamp(0.0, 1.0),
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
                                        isTrackFav ? Icons.favorite : Icons.favorite_border,
                                        color: isTrackFav ? Colors.redAccent : ResonXColors.textSecondary,
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final liveText = lyricsService.getLiveLine(player.position);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: ResonXColors.deepGraphite.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: ResonXColors.cyberJade, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: ResonXColors.cyberJade, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              liveText.isNotEmpty ? liveText : 'Wyszukiwanie tekstu LRCLIB w toku...',
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
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ResonXColors.deepGraphite,
        border: Border(
          top: BorderSide(color: ResonXColors.cardBorder, width: 1.5),
          bottom: BorderSide(color: ResonXColors.cardBorder, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
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
              child: ReorderableListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: player.queue.length,
                onReorder: (oldIndex, newIndex) {
                  player.reorderQueue(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = player.queue[index];
                  final isCurrent = index == player.currentIndex;

                  return Material(
                    key: ValueKey('queue_item_${item.id}_$index'),
                    color: isCurrent ? ResonXColors.cyberJade.withValues(alpha: 0.08) : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      tileColor: Colors.transparent,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            const Icon(Icons.volume_up, color: ResonXColors.cyberJade, size: 18),
                          const SizedBox(width: 8),
                          const Icon(Icons.drag_handle_rounded, color: Colors.white24, size: 20),
                        ],
                      ),
                      onTap: () {
                        player.playTrack(item);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}