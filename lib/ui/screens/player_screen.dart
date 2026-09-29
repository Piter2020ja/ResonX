import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/lyrics_service.dart';
import '../../services/downloader_service.dart';
import '../../main.dart';
import '../widgets/share_drop_sheet.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String? _lyricsText;
  bool _isLoadingLyrics = false;
  String? _lastTrackId;

  late AnimationController _spectrumController;
  late AnimationController _seekIndicatorController;
  int _seekFeedbackDirection = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _spectrumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _seekIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fetchLyricsIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchLyricsIfNeeded();
  }

  Future<void> _fetchLyricsIfNeeded() async {
    final player = Provider.of<AudioPlayerService>(context, listen: false);
    final track = player.currentTrack;
    if (track == null) return;

    if (_lastTrackId == track.id && _lyricsText != null) return;
    _lastTrackId = track.id;

    if (mounted) {
      setState(() {
        _isLoadingLyrics = true;
        _lyricsText = null;
      });
    }

    String? resolvedText;
    try {
      await LyricsService.instance.fetchLyrics(
        track.title,
        track.artist,
      );
      resolvedText = LyricsService.instance.getLiveLine(player.position);
    } catch (_) {
      resolvedText = 'Nie udało się pobrać tekstu utworu.';
    }

    if (mounted) {
      setState(() {
        _lyricsText = resolvedText;
        _isLoadingLyrics = false;
      });
    }
  }

  void _triggerSeekFeedback(int direction, AudioPlayerService player) {
    setState(() {
      _seekFeedbackDirection = direction;
    });
    final target = player.position + Duration(seconds: direction * 10);
    final maxSec = player.duration.inSeconds > 0 ? player.duration.inSeconds : 180;
    final clamped = Duration(seconds: target.inSeconds.clamp(0, maxSec));
    player.seek(clamped);

    _seekIndicatorController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _seekFeedbackDirection = 0;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.abs().toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '${d.isNegative ? '-' : ''}$minutes:$seconds';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spectrumController.dispose();
    _seekIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AudioPlayerService, BatterySaverService, DownloaderService>(
      builder: (context, player, batterySaver, downloader, child) {
        final track = player.currentTrack;

        if (track != null && _lastTrackId != track.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _fetchLyricsIfNeeded();
            }
          });
        }

        if (batterySaver.isBatterySaverEnabled) {
          if (_spectrumController.isAnimating) {
            _spectrumController.stop();
          }
        } else {
          if (!_spectrumController.isAnimating) {
            _spectrumController.repeat();
          }
        }

        final bool isOffline = track != null && downloader.isDownloadedLocally(track.id);
        final bool isDownloading = track != null && downloader.isDownloading(track.id);

        return Scaffold(
          backgroundColor: const Color(0xFF090A0F),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF111726),
                        Color(0xFF0A0C14),
                        Color(0xFF06070A),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'ODTWARZANIE Z KATALOGU',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  track?.album ?? 'SoundCloud HQ',
                                  style: const TextStyle(
                                    color: Color(0xFF00F2FE),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (track != null)
                            IconButton(
                              icon: const Icon(Icons.qr_code_2, color: Color(0xFF00F2FE)),
                              tooltip: 'ResonX ShareDrop',
                              onPressed: () {
                                ShareDropSheet.show(context, track: track);
                              },
                            ),
                          if (track != null)
                            IconButton(
                              icon: Icon(
                                player.favoriteTrackIds.contains(track.id) ? Icons.favorite : Icons.favorite_border,
                                color: player.favoriteTrackIds.contains(track.id) ? const Color(0xFFFF2A6D) : Colors.white70,
                              ),
                              tooltip: 'Ulubione',
                              onPressed: () => player.toggleFavorite(track),
                            ),
                          if (track != null)
                            IconButton(
                              icon: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F2FE)),
                                    )
                                  : Icon(
                                      isOffline ? Icons.download_done_rounded : Icons.download_rounded,
                                      color: isOffline ? const Color(0xFF00E676) : Colors.white70,
                                    ),
                              tooltip: isOffline ? 'Pobrano (Offline)' : 'Pobierz offline',
                              onPressed: () async {
                                if (isOffline) {
                                  await downloader.deleteDownloadedTrack(track.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Usunięto utwór z pamięci offline.')),
                                    );
                                  }
                                } else if (!isDownloading) {
                                  await downloader.downloadTrack(track);
                                }
                              },
                            ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white70),
                            color: const Color(0xFF141722),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'receive_drop') {
                                ShareDropSheet.showReceiveDropDialog(context);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'receive_drop',
                                child: Row(
                                  children: [
                                    Icon(Icons.downloading_rounded, color: Color(0xFF00F2FE), size: 20),
                                    SizedBox(width: 10),
                                    Text('Odbierz ShareDrop', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF00F2FE),
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      tabs: const [
                        Tab(text: 'Wizualizacja'),
                        Tab(text: 'Tekst na Żywo'),
                        Tab(text: 'Szczegóły & K'),
                      ],
                    ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // ---------------------------------------------------
                          // ZAKLADKA 1: GLOWNY WIDOK Z GESTAMI
                          // ---------------------------------------------------
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onHorizontalDragEnd: (details) {
                                      if (details.primaryVelocity != null) {
                                        if (details.primaryVelocity! < -300) {
                                          player.playNextTrack();
                                        } else if (details.primaryVelocity! > 300) {
                                          player.playPreviousTrack();
                                        }
                                      }
                                    },
                                    child: SizedBox(
                                      height: 310,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _spectrumController,
                                            builder: (context, child) {
                                              return CustomPaint(
                                                size: const Size(310, 310),
                                                painter: _AudioSpectrumPainter(
                                                  animationValue: _spectrumController.value,
                                                  isPlaying: player.isPlaying && !batterySaver.isBatterySaverEnabled,
                                                ),
                                              );
                                            },
                                          ),
                                          Container(
                                            width: 240,
                                            height: 240,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF00F2FE).withValues(alpha: 0.22),
                                                  blurRadius: 36,
                                                  spreadRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(20),
                                              child: track?.coverUrl != null && track!.coverUrl.startsWith('http')
                                                  ? Image.network(
                                                      track.coverUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.grey[900],
                                                        child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: Colors.grey[900],
                                                      child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                                                    ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 35,
                                            top: 40,
                                            bottom: 40,
                                            width: 100,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onDoubleTap: () => _triggerSeekFeedback(-1, player),
                                              onTap: () => player.togglePlayPause(),
                                            ),
                                          ),
                                          Positioned(
                                            right: 35,
                                            top: 40,
                                            bottom: 40,
                                            width: 100,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onDoubleTap: () => _triggerSeekFeedback(1, player),
                                              onTap: () => player.togglePlayPause(),
                                            ),
                                          ),
                                          if (_seekFeedbackDirection != 0)
                                            FadeTransition(
                                              opacity: ReverseAnimation(_seekIndicatorController),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.75),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: const Color(0xFF00F2FE)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _seekFeedbackDirection > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                                                      color: const Color(0xFF00F2FE),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _seekFeedbackDirection > 0 ? '+10s' : '-10s',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    track?.title ?? 'Brak wybranego utworu',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    track?.artist ?? 'ResonX Engine',
                                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 20),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      activeTrackColor: const Color(0xFF00F2FE),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: player.position.inSeconds.toDouble().clamp(
                                            0.0,
                                            (player.duration.inSeconds > 0 ? player.duration.inSeconds : 180).toDouble(),
                                          ),
                                      max: (player.duration.inSeconds > 0 ? player.duration.inSeconds : 180).toDouble(),
                                      onChanged: (val) {
                                        player.seek(Duration(seconds: val.toInt()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(player.position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        Text(_formatDuration(player.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.shuffle,
                                          color: player.isShuffleMode ? const Color(0xFF00F2FE) : Colors.white60,
                                        ),
                                        onPressed: () => player.toggleShuffle(),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 34),
                                        onPressed: () => player.playPreviousTrack(),
                                      ),
                                      Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF00F2FE), Color(0xFF00E676)],
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            player.isPlaying ? Icons.pause : Icons.play_arrow,
                                            color: Colors.black,
                                            size: 38,
                                          ),
                                          onPressed: () => player.togglePlayPause(),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 34),
                                        onPressed: () => player.playNextTrack(),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.repeat,
                                          color: player.isLoopMode ? const Color(0xFF00F2FE) : Colors.white60,
                                        ),
                                        onPressed: () => player.toggleLoop(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),

                          // ---------------------------------------------------
                          // ZAKLADKA 2: TEKSTY NA ZYWO
                          // ---------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: _isLoadingLyrics
                                  ? const CircularProgressIndicator(color: Color(0xFF00F2FE))
                                  : StreamBuilder<Duration>(
                                      stream: player.positionStream,
                                      builder: (context, snapshot) {
                                        final currentPos = snapshot.data ?? player.position;
                                        final liveLine = LyricsService.instance.getLiveLine(currentPos);
                                        return SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (liveLine.isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    liveLine,
                                                    style: const TextStyle(
                                                      color: Color(0xFF00F2FE),
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      height: 1.5,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                              ],
                                              Text(
                                                _lyricsText ?? 'Brak synchronizowanego tekstu dla tego utworu.',
                                                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.8),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),

                          // ---------------------------------------------------
                          // ZAKLADKA 3: SZCZEGOLY & KOLEJKA (BEZ BLEDOW OVERFLOW)
                          // ---------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DANE TECHNICZNE AUDIOPHILE',
                                  style: TextStyle(color: Color(0xFF00F2FE), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            flex: 5,
                                            child: Text('Platforma / Tryb odtwarzania', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 6,
                                            child: Text(
                                              isOffline ? 'Lokalny Plik Offline' : 'Strumień Bezpośredni Cloud',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.white12, height: 18),
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text('Format kontenera', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                          ),
                                          Expanded(
                                            child: Text(
                                              track?.fileFormat ?? 'HQ Audio (M4A/MP3)',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.white12, height: 18),
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text('Bitrate strumienia', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${track?.bitrate ?? 320} kbps HQ',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.white12, height: 18),
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text('Częstotliwość próbkowania', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${track?.sampleRate ?? 48000} Hz',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'KOLEJKA ODTWARZANIA (${player.queue.length})',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Text(
                                      'Przytrzymaj, aby zmienić',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
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
                                        key: ValueKey(item.id),
                                        color: isCurrent ? const Color(0xFF00F2FE).withValues(alpha: 0.08) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        child: ListTile(
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: item.coverUrl.isNotEmpty && item.coverUrl.startsWith('http')
                                                ? Image.network(
                                                    item.coverUrl,
                                                    width: 42,
                                                    height: 42,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[850], width: 42, height: 42),
                                                  )
                                                : Container(color: Colors.grey[850], width: 42, height: 42),
                                          ),
                                          title: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: isCurrent ? const Color(0xFF00F2FE) : Colors.white,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(item.artist, style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isCurrent)
                                                const Icon(Icons.volume_up, color: Color(0xFF00F2FE), size: 20),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.drag_handle_rounded, color: Colors.white30, size: 22),
                                            ],
                                          ),
                                          onTap: () => player.playTrack(item),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AudioSpectrumPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;

  _AudioSpectrumPainter({required this.animationValue, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 132.0;
    const barCount = 56;
    const angleStep = (2 * math.pi) / barCount;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final angle = i * angleStep;

      double heightFactor = 0.0;
      if (isPlaying) {
        final harmonic1 = math.sin((animationValue * 2 * math.pi) + (i * 0.35));
        final harmonic2 = math.cos((animationValue * 3.5 * math.pi) - (i * 0.25));
        final harmonic3 = math.sin((animationValue * 5 * math.pi) + (i * 0.15));
        heightFactor = ((harmonic1.abs() * 0.5) + (harmonic2.abs() * 0.35) + (harmonic3.abs() * 0.15));
      } else {
        heightFactor = 0.12;
      }

      final barLength = 8.0 + (heightFactor * 38.0);

      final startX = center.dx + (radius * math.cos(angle));
      final startY = center.dy + (radius * math.sin(angle));
      final endX = center.dx + ((radius + barLength) * math.cos(angle));
      final endY = center.dy + ((radius + barLength) * math.sin(angle));

      paint.color = i % 2 == 0
          ? const Color(0xFF00F2FE).withValues(alpha: 0.55 + (heightFactor * 0.45))
          : const Color(0xFF00E676).withValues(alpha: 0.45 + (heightFactor * 0.45));

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioSpectrumPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isPlaying != isPlaying;
  }
}