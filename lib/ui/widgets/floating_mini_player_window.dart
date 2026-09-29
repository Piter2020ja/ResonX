import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../core/theme.dart';
import '../screens/player_screen.dart';

class FloatingMiniPlayerWindow extends StatefulWidget {
  const FloatingMiniPlayerWindow({super.key});

  @override
  State<FloatingMiniPlayerWindow> createState() => _FloatingMiniPlayerWindowState();
}

class _FloatingMiniPlayerWindowState extends State<FloatingMiniPlayerWindow>
    with SingleTickerProviderStateMixin {
  Offset? _position;
  bool _isExpanded = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final screenSize = MediaQuery.of(context).size;
        final topPadding = MediaQuery.of(context).padding.top;

        // Domyślna pozycja: wycentrowana pigułka pod aparatem/paskiem stanu
        final double expandedWidth = math.min(screenSize.width - 24.0, 360.0);
        final double collapsedWidth = 210.0;
        final double currentWidth = _isExpanded ? expandedWidth : collapsedWidth;
        final double currentHeight = _isExpanded ? 155.0 : 44.0;

        _position ??= Offset((screenSize.width - collapsedWidth) / 2, topPadding + 6.0);

        final isFav = player.favoriteTrackIds.contains(track.id);

        return Positioned(
          left: _position!.dx.clamp(6.0, screenSize.width - currentWidth - 6.0),
          top: _position!.dy.clamp(topPadding + 2.0, screenSize.height - currentHeight - 16.0),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    _position!.dx + details.delta.dx,
                    _position!.dy + details.delta.dy,
                  );
                });
              },
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.fastOutSlowIn,
                width: currentWidth,
                height: currentHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: _isExpanded ? 12.0 : 8.0,
                  vertical: _isExpanded ? 10.0 : 4.0,
                ),
                decoration: BoxDecoration(
                  color: ResonXColors.surfaceBlack.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(_isExpanded ? 22.0 : 26.0),
                  border: Border.all(
                    color: ResonXColors.cyberJade.withValues(alpha: _isExpanded ? 0.7 : 0.45),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: ResonXColors.cyberJade.withValues(alpha: player.isPlaying ? 0.18 : 0.04),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_isExpanded ? 18.0 : 22.0),
                  child: OverflowBox(
                    minWidth: 0.0,
                    maxWidth: currentWidth,
                    minHeight: 0.0,
                    maxHeight: currentHeight,
                    alignment: Alignment.center,
                    child: _isExpanded
                        ? _buildExpandedIslandView(context, player, track, isFav)
                        : _buildCollapsedPillView(player, track),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- ZWINIĘTA PIGUŁKA DYNAMIC ISLAND ---
  Widget _buildCollapsedPillView(AudioPlayerService player, dynamic track) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: track.coverUrl.isNotEmpty && track.coverUrl.startsWith('http')
              ? Image.network(
                  track.coverUrl,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.music_note, color: ResonXColors.cyberJade, size: 16),
                  ),
                )
              : Container(
                  color: Colors.grey[900],
                  width: 30,
                  height: 30,
                  child: const Icon(Icons.music_note, color: ResonXColors.cyberJade, size: 16),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: const TextStyle(
                  color: ResonXColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              _buildMiniWaveform(player.isPlaying),
            ],
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => player.togglePlayPause(),
          child: Icon(
            player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: ResonXColors.cyberJade,
            size: 26,
          ),
        ),
      ],
    );
  }

  // --- ROZSZERZONA KARTA MULTIMEDIALNA ---
  Widget _buildExpandedIslandView(BuildContext context, AudioPlayerService player, dynamic track, bool isFav) {
    final curPos = player.position.inSeconds.toDouble();
    final maxDur = (player.duration.inSeconds > 0 ? player.duration.inSeconds : 180).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.coverUrl.isNotEmpty && track.coverUrl.startsWith('http')
                    ? Image.network(
                        track.coverUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.grey[900],
                          child: const Icon(Icons.music_note, color: ResonXColors.cyberJade),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: Colors.grey[900],
                        child: const Icon(Icons.music_note, color: ResonXColors.cyberJade),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: ResonXColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    style: const TextStyle(
                      color: ResonXColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF2A6D) : Colors.white70,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => player.toggleFavorite(track),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.open_in_full_rounded, color: ResonXColors.neonCyan, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Pełny ekran odtwarzacza',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              _formatDuration(player.position),
              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                  activeTrackColor: ResonXColors.cyberJade,
                  inactiveTrackColor: ResonXColors.deepGraphite,
                  thumbColor: ResonXColors.cyberJade,
                ),
                child: Slider(
                  value: curPos.clamp(0.0, maxDur),
                  min: 0.0,
                  max: maxDur,
                  onChanged: (val) {
                    player.seek(Duration(seconds: val.toInt()));
                  },
                ),
              ),
            ),
            Text(
              _formatDuration(player.duration),
              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                color: player.isShuffleMode ? ResonXColors.cyberJade : Colors.white38,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => player.toggleShuffle(),
            ),
            IconButton(
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final target = player.position - const Duration(seconds: 10);
                player.seek(target < Duration.zero ? Duration.zero : target);
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => player.playPreviousTrack(),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => player.togglePlayPause(),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ResonXColors.cyberJade,
                ),
                child: Icon(
                  player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => player.playNextTrack(),
            ),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final target = player.position + const Duration(seconds: 10);
                player.seek(target);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.repeat_rounded,
                color: player.isLoopMode ? ResonXColors.cyberJade : Colors.white38,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => player.toggleLoop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniWaveform(bool isPlaying) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          children: List.generate(10, (index) {
            double height = 2.5;
            if (isPlaying) {
              final wave = math.sin((_waveController.value * 2 * math.pi) + (index * 0.6));
              height = 2.5 + (wave.abs() * 6.5);
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.8),
              width: 1.8,
              height: height,
              decoration: BoxDecoration(
                color: ResonXColors.cyberJade.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(1.0),
              ),
            );
          }),
        );
      },
    );
  }
}