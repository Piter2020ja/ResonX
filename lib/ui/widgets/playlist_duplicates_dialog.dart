import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/duplicate_finder_service.dart';

class PlaylistDuplicatesDialog extends StatefulWidget {
  final List<Track> currentPlaylistTracks;
  const PlaylistDuplicatesDialog({super.key, required this.currentPlaylistTracks});

  @override
  State<PlaylistDuplicatesDialog> createState() => _PlaylistDuplicatesDialogState();
}

class _PlaylistDuplicatesDialogState extends State<PlaylistDuplicatesDialog> {
  late List<List<Track>> _duplicates;

  @override
  void initState() {
    super.initState();
    _duplicates = DuplicateFinderService.instance.findDuplicates(widget.currentPlaylistTracks);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.copy_all, color: Color(0xFF1DB954)),
                    SizedBox(width: 12),
                    Text(
                      'Wyszukiwanie Duplikatów w Playliście',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: _duplicates.isEmpty
                  ? const Center(
                      child: Text(
                        'Brak duplikatów w bieżącej playliście. Wszystko jest czyste!',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _duplicates.length,
                      itemBuilder: (context, index) {
                        final group = _duplicates[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grupa: ${group.first.title} (${group.length} kopie)',
                                style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              ...group.map((t) => Text(
                                    '• ID: ${t.id} | ${t.artist}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white12, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zamknij', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 12),
                if (_duplicates.isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
                    onPressed: () {
                      DuplicateFinderService.instance.removeDuplicates(widget.currentPlaylistTracks);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pomyślnie scalono i usunięto duplikaty z playlisty!')),
                      );
                    },
                    child: const Text('Scal i Usuń Duplikaty', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}