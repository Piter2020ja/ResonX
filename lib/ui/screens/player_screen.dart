import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/lyrics_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _lyricsText;
  bool _isLoadingLyrics = false;
  String? _lastTrackId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      // Ponieważ fetchLyrics zwraca void, wywołujemy ją bezpośrednio,
      // a tekst pobieramy z instancji serwisu (np. za pomocą metody getLiveLine lub podobnej, 
      // albo zostawiamy komunikat, że tekst jest synchronizowany).
      await LyricsService.instance.fetchLyrics(
        track.title,
        track.artist,
      );
      
      // Pobieramy aktualny tekst z serwisu po wykonaniu zapytania
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, player, child) {
        final track = player.currentTrack;

        if (track != null && _lastTrackId != track.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _fetchLyricsIfNeeded();
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
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
                  style: const TextStyle(color: Color(0xFF1DB954), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.equalizer, color: Colors.white70),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.qr_code, color: Colors.white70),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () {},
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1DB954),
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
              // --- ZAKŁADKA 1: WIZUALIZACJA ---
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: track?.coverUrl != null && track!.coverUrl.startsWith('http')
                              ? Image.network(track.coverUrl, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[850],
                                  child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        track?.title ?? 'Brak utworu',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track?.artist ?? 'Nieznany wykonawca',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 30),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: const Color(0xFF1DB954),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: player.isShuffleMode ? const Color(0xFF1DB954) : Colors.white60,
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
                              color: Color(0xFF1DB954),
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
                              color: player.isLoopMode ? const Color(0xFF1DB954) : Colors.white60,
                            ),
                            onPressed: () => player.toggleLoop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // --- ZAKŁADKA 2: TEKST NA ŻYWO (KARAOKE) ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: _isLoadingLyrics
                      ? const CircularProgressIndicator(color: Color(0xFF1DB954))
                      : SingleChildScrollView(
                          child: Text(
                            _lyricsText ?? 'Brak tekstu dla tego utworu.',
                            style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),

              // --- ZAKŁADKA 3: SZCZEGÓŁY & KOLEJKA ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DANE TECHNICZNE AUDIOPHILE',
                      style: TextStyle(color: Color(0xFF1DB954), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Format kontenera', style: TextStyle(color: Colors.white60)),
                              Text(track?.fileFormat ?? 'HQ Audio (M4A)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        itemCount: player.queue.length,
                        itemBuilder: (context, index) {
                          final item = player.queue[index];
                          final isCurrent = index == player.currentIndex;
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(item.coverUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 40, height: 40)),
                            ),
                            title: Text(item.title, style: TextStyle(color: isCurrent ? const Color(0xFF1DB954) : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal), maxLines: 1),
                            subtitle: Text(item.artist, style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1),
                            trailing: isCurrent ? const Icon(Icons.volume_up, color: Color(0xFF1DB954), size: 20) : null,
                            onTap: () => player.playTrack(item),
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