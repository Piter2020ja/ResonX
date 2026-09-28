import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/api_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/downloader_service.dart';

class ResonXPalette {
  static const Color background = Color(0xFF090A0F);
  static const Color surfaceSidebar = Color(0xFF0D0E15);
  static const Color surfaceCard = Color(0xFF131520);
  static const Color surfaceCardHover = Color(0xFF1C1F30);
  static const Color surfaceSearchBar = Color(0xFF12141D);

  static const Color neonCyan = Color(0xFF00F2FE);
  static const Color neonPurple = Color(0xFF9B51E0);
  static const Color neonMint = Color(0xFF00E676);
  static const Color neonCoral = Color(0xFFFF5252);
  static const Color neonAmber = Color(0xFFFFB300);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color textDim = Color(0xFF535868);

  static const Color borderLight = Color(0xFF1F2333);
  static const Color borderGlow = Color(0x3300F2FE);
}

class TrackOptionsSheet extends StatelessWidget {
  final Track track;
  const TrackOptionsSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<AudioPlayerService>();
    final downloaderService = context.watch<DownloaderService>();
    
    // Bezpieczne sprawdzenie statusów za pomocą track.id (likwidacja błędów typowania)
    final isFav = playerService.favoriteTrackIds.contains(track.id);
    final isDownloading = downloaderService.isDownloading(track.id);
    final isDownloaded = downloaderService.isDownloadedLocally(track.id) || 
                         (track.localPath != null && track.localPath!.isNotEmpty);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: ResonXPalette.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: ResonXPalette.borderLight, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Górny wskaźnik przeciągania
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ResonXPalette.textDim,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header utworu z okładką Ultra-HD
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          track.coverUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: ResonXPalette.surfaceCardHover,
                            child: const Icon(Icons.music_note, color: ResonXPalette.textDim),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                color: ResonXPalette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              style: const TextStyle(
                                color: ResonXPalette.textSecondary,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: ResonXPalette.neonCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ResonXPalette.neonCyan.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Lossless Audio HQ',
                                style: TextStyle(
                                  color: ResonXPalette.neonCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: ResonXPalette.borderLight, height: 28),

                  // Lista akcji opcji utworu
                  _buildOptionTile(
                    icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: isFav ? ResonXPalette.neonCoral : ResonXPalette.textSecondary,
                    title: isFav ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                    subtitle: 'Zarządzaj biblioteką polubionych utworów',
                    onTap: () {
                      playerService.toggleFavorite(track);
                      Navigator.pop(context);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.playlist_add_rounded,
                    iconColor: ResonXPalette.neonCyan,
                    title: 'Odtwórz jako następny w kolejce',
                    subtitle: 'Wstaw na sam początek bieżącej playlisty odtwarzania',
                    onTap: () {
                      playerService.insertNext(track);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Wstawiono "${track.title}" jako następny!')),
                      );
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.queue_music_rounded,
                    iconColor: ResonXPalette.neonMint,
                    title: 'Dodaj na koniec kolejki',
                    subtitle: 'Dołącz do aktywnej kolejki odtwarzacza',
                    onTap: () {
                      playerService.addToQueue(track);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dodano "${track.title}" do kolejki!')),
                      );
                    },
                  ),
                  _buildOptionTile(
                    icon: isDownloading 
                        ? Icons.hourglass_top_rounded 
                        : (isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded),
                    iconColor: isDownloaded ? ResonXPalette.neonMint : ResonXPalette.neonAmber,
                    title: isDownloaded 
                        ? 'Pobrano do pamięci offline' 
                        : (isDownloading ? 'Pobieranie w toku...' : 'Pobierz utwór offline (HQ M4A)'),
                    subtitle: 'Zapisz plik bezpośrednio na dysku komputera z systemem Windows',
                    onTap: isDownloading ? () {} : () async {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rozpoczęto pobieranie pliku: ${track.title}')),
                      );
                      await downloaderService.downloadTrack(track);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.lyrics_outlined,
                    iconColor: ResonXPalette.neonPurple,
                    title: 'Pokaż tekst utworu (Synchronized Karaoke)',
                    subtitle: 'Zsynchronizowane wersy tekstowe pobierane w czasie rzeczywistym',
                    onTap: () {
                      Navigator.pop(context);
                      _showLyricsBottomSheet(context, track);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.share_rounded,
                    iconColor: ResonXPalette.textSecondary,
                    title: 'Kopiuj link / udostępnij',
                    subtitle: 'Skopiuj identyfikator utworu do schowka',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '${track.artist} - ${track.title}'));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Skopiowano informacje o utworze do schowka!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Przycisk zamknięcia sheetu
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ResonXPalette.textSecondary,
                        side: const BorderSide(color: ResonXPalette.borderLight),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Zamknij',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: ResonXPalette.surfaceCardHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ResonXPalette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ResonXPalette.textDim,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: ResonXPalette.textDim, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLyricsBottomSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ResonXPalette.neonPurple, width: 1.2),
      ),
      builder: (ctx) {
        return FutureBuilder<List<ResonXLrcLine>>(
          future: ApiService.instance.fetchSynchronizedLyrics(track),
          builder: (context, snapshot) {
            final lyrics = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Container(
              height: 520,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lyrics, color: ResonXPalette.neonPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${track.title} – ${track.artist}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: ResonXPalette.textDim),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: ResonXPalette.borderLight),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: ResonXPalette.neonPurple),
                          )
                        : (lyrics.isEmpty
                            ? const Center(
                                child: Text(
                                  'Brak zsynchronizowanego tekstu w bazie LRCLIB dla tego utworu.',
                                  style: TextStyle(color: ResonXPalette.textDim),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: lyrics.length,
                                itemBuilder: (context, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      lyrics[i].text,
                                      style: TextStyle(
                                        color: i == 0 ? ResonXPalette.neonMint : Colors.white70,
                                        fontSize: i == 0 ? 16 : 14,
                                        fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}