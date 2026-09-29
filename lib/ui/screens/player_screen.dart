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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _spectrumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

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
          backgroundColor: const Color(0xFF0A0B10),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              children: [
                const Text(
                  'ODTWARZANIE Z KATALOGU',
                  style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  track?.album ?? 'ResonX Master Cloud',
                  style: const TextStyle(color: Color(0xFF00F2FE), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00F2FE),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Wizualizacja'),
                Tab(text: 'Tekst na Żywo (LRC)'),
                Tab(text: 'Szczegóły & Kolejka'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
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
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00F2FE).withValues(alpha: 0.25),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
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
                          ],
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
                      const SizedBox(height: 8),
                      Text(
                        track?.artist ?? 'ResonX Engine',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
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
                            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                            onPressed: () => player.playPreviousTrack(),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00F2FE),
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 36,
                              ),
                              onPressed: () => player.togglePlayPause(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Platforma / Tryb odtwarzania', style: TextStyle(color: Colors.white60)),
                              Text(
                                isOffline ? 'Lokalny Plik Offline' : 'Strumień Bezpośredni Cloud',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Format kontenera', style: TextStyle(color: Colors.white60)),
                              Text(track?.fileFormat ?? 'HQ Audio (M4A/MP3)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bitrate strumienia', style: TextStyle(color: Colors.white60)),
                              Text('${track?.bitrate ?? 320} kbps HQ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Częstotliwość próbkowania', style: TextStyle(color: Colors.white60)),
                              Text('${track?.sampleRate ?? 48000} Hz', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'KOLEJKA ODTWARZANIA (${player.queue.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: player.queue.length,
                        itemBuilder: (context, index) {
                          final item = player.queue[index];
                          final isCurrent = index == player.currentIndex;
                          return Material(
                            color: Colors.transparent,
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
                              ),
                              subtitle: Text(item.artist, style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1),
                              trailing: isCurrent ? const Icon(Icons.volume_up, color: Color(0xFF00F2FE), size: 20) : null,
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
    const radius = 135.0;
    const barCount = 48;
    const angleStep = (2 * math.pi) / barCount;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final angle = i * angleStep;

      double heightFactor = 0.0;
      if (isPlaying) {
        final wave = math.sin((animationValue * 2 * math.pi) + (i * 0.4));
        final wave2 = math.cos((animationValue * 4 * math.pi) - (i * 0.2));
        heightFactor = ((wave.abs() * 0.7) + (wave2.abs() * 0.3));
      } else {
        heightFactor = 0.15;
      }

      final barLength = 10.0 + (heightFactor * 35.0);

      final startX = center.dx + (radius * math.cos(angle));
      final startY = center.dy + (radius * math.sin(angle));
      final endX = center.dx + ((radius + barLength) * math.cos(angle));
      final endY = center.dy + ((radius + barLength) * math.sin(angle));

      paint.color = i % 2 == 0
          ? const Color(0xFF00F2FE).withValues(alpha: 0.6 + (heightFactor * 0.4))
          : const Color(0xFF9B51E0).withValues(alpha: 0.4 + (heightFactor * 0.4));

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioSpectrumPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isPlaying != isPlaying;
  }
}