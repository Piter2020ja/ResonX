import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';

class FloatingMiniPlayerWindow extends StatelessWidget {
  const FloatingMiniPlayerWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return Container(
          width: 320,
          height: 90,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF181818).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.coverUrl.startsWith('http')
                    ? Image.network(track.coverUrl, width: 64, height: 64, fit: BoxFit.cover)
                    : Container(color: Colors.grey[850], width: 64, height: 64, child: const Icon(Icons.music_note, color: Colors.white54)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ResonX Floating Overlay',
                      style: TextStyle(color: Color(0xFF1DB954), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                    onPressed: () => player.togglePlayPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                    onPressed: () => player.playNextTrack(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}