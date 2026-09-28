import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/track.dart';
import '../../services/playlist_service.dart';

/// Dolny arkusz wyboru playlisty z wykrywaniem duplikatów
class AddToPlaylistSheet extends StatelessWidget {
  final Track track;

  const AddToPlaylistSheet({super.key, required this.track});

  static void show(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXColors.deepGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddToPlaylistSheet(track: track),
    );
  }

  void _showNewPlaylistDialog(BuildContext context, PlaylistService playlistService) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ResonXColors.deepGraphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nowa playlista',
          style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: ResonXColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nazwa playlisty...',
            hintStyle: TextStyle(color: ResonXColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ResonXColors.cardBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ResonXColors.cyberJade),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: ResonXColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ResonXColors.cyberJade,
              foregroundColor: ResonXColors.deepGraphite,
            ),
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                playlistService.createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Utwórz', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleTrackAddition(BuildContext context, PlaylistService service, Playlist playlist) {
    final check = service.checkForDuplicate(playlist, track);

    if (check.status == DuplicateStatus.none) {
      service.addTrackToPlaylist(playlist.id, track);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dodano "${track.title}" do "${playlist.title}"'),
          backgroundColor: ResonXColors.cyberJade,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Wykryto duplikat – pokazujemy okno rozwiązania konfliktu
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ResonXColors.deepGraphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'Wykryto duplikat',
              style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          check.status == DuplicateStatus.exactMatch
              ? 'Ten utwór znajduje się już na playliście "${playlist.title}". Co chcesz zrobić?'
              : 'Na playliście istnieje już bardzo podobny utwór (${check.existingTrack?.title} - ${check.existingTrack?.artist}).',
          style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Zamknięcie dialogu
              Navigator.pop(context); // Zamknięcie arkusza
            },
            child: const Text('Pomiń', style: TextStyle(color: ResonXColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              service.addTrackToPlaylist(playlist.id, track, replaceExisting: true);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Zastąpiono utwór na "${playlist.title}"'),
                  backgroundColor: ResonXColors.neonCyan,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Zastąp', style: TextStyle(color: ResonXColors.neonCyan)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ResonXColors.cyberJade,
              foregroundColor: ResonXColors.deepGraphite,
            ),
            onPressed: () {
              service.addTrackToPlaylist(playlist.id, track, replaceExisting: false);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dodano duplikat do "${playlist.title}"'),
                  backgroundColor: ResonXColors.cyberJade,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Dodaj mimo to', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistService = context.watch<PlaylistService>();
    final playlists = playlistService.playlists;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ResonXColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dodaj do playlisty',
                  style: TextStyle(
                    color: ResonXColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, color: ResonXColors.cyberJade, size: 20),
                  label: const Text('Nowa', style: TextStyle(color: ResonXColors.cyberJade)),
                  onPressed: () => _showNewPlaylistDialog(context, playlistService),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.queue_music_rounded, size: 48, color: ResonXColors.cardBorder),
                      SizedBox(height: 12),
                      Text(
                        'Brak utworzonych playlist',
                        style: TextStyle(color: ResonXColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ResonXColors.cardBorder.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.playlist_play_rounded, color: ResonXColors.cyberJade),
                      ),
                      title: Text(
                        playlist.title,
                        style: const TextStyle(
                          color: ResonXColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${playlist.trackCount} utworów',
                        style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: ResonXColors.textSecondary),
                      onTap: () => _handleTrackAddition(context, playlistService, playlist),
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