import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/local_scanner_service.dart';
import '../../models/track.dart';

class LocalLibraryScreen extends StatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  State<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends State<LocalLibraryScreen> {
  List<Track> _localTracks = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scanLibrary();
  }

  Future<void> _scanLibrary() async {
    setState(() {
      _isScanning = true;
    });

    final results = await LocalScannerService.instance.scanWindowsMusicDirectory();

    if (mounted) {
      setState(() {
        _localTracks = results;
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Lokalna Biblioteka Windows (.FLAC / .MP3)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1DB954)),
            onPressed: _isScanning ? null : _scanLibrary,
            tooltip: 'Skanuj folder Muzyka',
          ),
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1DB954)),
                  SizedBox(height: 16),
                  Text(
                    'Skanowanie dysku C:\\Users\\...\\Music...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            )
          : _localTracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Nie znaleziono lokalnych plików audio w katalogu muzycznym.',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
                        onPressed: _scanLibrary,
                        child: const Text('Skanuj Ponownie', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localTracks.length,
                  itemBuilder: (context, index) {
                    final track = _localTracks[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.audiotrack, color: Color(0xFF1DB954)),
                        ),
                        title: Text(
                          track.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${track.fileFormat} • ${track.bitrate} kbps • ${track.localPath}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Color(0xFF1DB954)),
                          onPressed: () {
                            Provider.of<AudioPlayerService>(context, listen: false).playTrack(track);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}