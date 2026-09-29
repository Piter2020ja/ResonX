import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/database_service.dart';
import '../../services/smart_features_service.dart';

class ShareDropSheet extends StatefulWidget {
  final Track? track;
  final String? playlistName;
  final List<Track>? playlistTracks;

  const ShareDropSheet({
    super.key,
    this.track,
    this.playlistName,
    this.playlistTracks,
  }) : assert(track != null || playlistName != null, 'Należy podać utwór lub playlistę');

  /// Globalna metoda otwierająca arkusz udostępniania utworu lub playlisty
  static void show(BuildContext context, {Track? track, String? playlistName, List<Track>? playlistTracks}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareDropSheet(
        track: track,
        playlistName: playlistName,
        playlistTracks: playlistTracks,
      ),
    );
  }

  /// Globalny dialog odbierania i importowania z linku / kodu ShareDrop
  static void showReceiveDropDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1016),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00F2FE), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.downloading_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Odbierz ResonX Drop', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wklej otrzymany link ShareDrop (https://resonx.app/drop?data=...):',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Wklej link lub token z drugiego urządzenia...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF161924),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
            onPressed: () async {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;

              try {
                String payload = raw;
                if (payload.contains('data=')) {
                  payload = payload.split('data=')[1];
                }
                final decodedJson = utf8.decode(base64Url.decode(payload));
                final Map<String, dynamic> map = jsonDecode(decodedJson);

                if (map['type'] == 'playlist') {
                  final String plName = map['name'] ?? 'Udostępniona Playlista';
                  final List rawList = map['tracks'] ?? [];
                  final tracks = rawList.map((m) => Track(
                    id: m['id'] ?? 'imported_${DateTime.now().millisecondsSinceEpoch}',
                    title: m['title'] ?? 'Nieznany',
                    artist: m['artist'] ?? 'Nieznany',
                    album: m['album'] ?? '',
                    audioUrl: m['audioUrl'] ?? '',
                    coverUrl: m['coverUrl'] ?? '',
                    durationSeconds: m['durationSeconds'] ?? 0,
                  )).toList();

                  for (final t in tracks) {
                    await DatabaseService.instance.toggleFavorite(t);
                  }

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Zaimportowano playlistę "$plName" (${tracks.length} utworów)!')),
                    );
                    if (tracks.isNotEmpty) {
                      AudioPlayerService.instance.setQueue(tracks, startIndex: 0);
                    }
                  }
                } else if (map['type'] == 'track') {
                  final m = map['track'];
                  final track = Track(
                    id: m['id'] ?? 'imported_${DateTime.now().millisecondsSinceEpoch}',
                    title: m['title'] ?? 'Nieznany',
                    artist: m['artist'] ?? 'Nieznany',
                    album: m['album'] ?? '',
                    audioUrl: m['audioUrl'] ?? '',
                    coverUrl: m['coverUrl'] ?? '',
                    durationSeconds: m['durationSeconds'] ?? 0,
                  );

                  await DatabaseService.instance.toggleFavorite(track);

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    AudioPlayerService.instance.playTrack(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Zaimportowano i włączono utwór "${track.title}"!')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd odczytu danych Drop: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Importuj i Odtwórz', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  State<ShareDropSheet> createState() => _ShareDropSheetState();
}

class _ShareDropSheetState extends State<ShareDropSheet> {
  late String _sharePayload;
  late String _dropCode;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _generateRealShareData();
  }

  void _generateRealShareData() {
    final Map<String, dynamic> data = {
      'app': 'ResonX',
      'v': 2,
      'type': widget.playlistName != null ? 'playlist' : 'track',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (widget.playlistName != null) {
      data['name'] = widget.playlistName;
      data['tracks'] = (widget.playlistTracks ?? []).map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'audioUrl': t.audioUrl,
        'coverUrl': t.coverUrl,
        'durationSeconds': t.durationSeconds,
      }).toList();
    } else if (widget.track != null) {
      data['track'] = {
        'id': widget.track!.id,
        'title': widget.track!.title,
        'artist': widget.track!.artist,
        'album': widget.track!.album,
        'audioUrl': widget.track!.audioUrl,
        'coverUrl': widget.track!.coverUrl,
        'durationSeconds': widget.track!.durationSeconds,
      };
    }

    final jsonStr = jsonEncode(data);
    final base64Data = base64UrlEncode(utf8.encode(jsonStr));
    _sharePayload = 'https://resonx.app/drop?data=$base64Data';

    final hashSource = widget.playlistName ?? widget.track!.id;
    final int codeNum = (hashSource.hashCode ^ DateTime.now().millisecondsSinceEpoch).abs() % 900000 + 100000;
    _dropCode = 'RX-$codeNum';
  }

  void _copyShareLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _sharePayload));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF161922),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: ResonXColors.cyberJade, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.playlistName != null
                    ? 'Skopiowano odnośnik do playlisty "${widget.playlistName}" (${widget.playlistTracks?.length ?? 0} utworów)!'
                    : 'Skopiowano odnośnik do utworu "${widget.track!.title}"!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final smart = SmartFeaturesService.instance;
    final isPlaylist = widget.playlistName != null;
    final titleText = isPlaylist ? 'Playlista: ${widget.playlistName}' : widget.track!.title;
    final subText = isPlaylist ? '${widget.playlistTracks?.length ?? 0} utworów w paczce' : widget.track!.artist;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
      decoration: const BoxDecoration(
        color: ResonXColors.surfaceBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: ResonXColors.cardBorder, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(isPlaylist ? Icons.queue_music_rounded : Icons.qr_code_2, color: ResonXColors.cyberJade, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPlaylist ? 'ResonX Playlist Drop' : 'ResonX Track Drop',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ResonXColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: ResonXColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.black38,
                    child: (isPlaylist || widget.track?.coverUrl == null)
                        ? const Icon(Icons.library_music_rounded, color: ResonXColors.cyberJade)
                        : Image.network(
                            widget.track!.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white30),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subText, style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ResonXColors.cyberJade.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ResonXColors.cyberJade.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isPlaylist ? 'PLAYLISTA' : 'UTWÓR',
                    style: const TextStyle(color: ResonXColors.cyberJade, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 170,
              height: 170,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ResonXColors.cyberJade.withValues(alpha: 0.25),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(116, 116),
                    painter: _ResonXQrPatternPainter(dataSeed: _sharePayload.hashCode),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dropCode,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isPlaylist
                ? 'Zeskanuj kod QR lub prześlij link, aby drugi telefon natychmiast zaimportował i odtworzył całą playlistę!'
                : 'Zeskanuj kod QR lub prześlij link, aby natychmiast odtworzyć "${widget.track!.title}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ResonXColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.groups_rounded, color: ResonXColors.neonCyan, size: 18),
                  label: const Text('Party Mode', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    smart.startPartyMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Utworzono pokój Party Mode: ${smart.partyRoomCode}')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCopied ? const Color(0xFF00E676) : const Color(0xFF00F2FE),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_isCopied ? Icons.check : Icons.copy_rounded, size: 18),
                  label: Text(_isCopied ? 'Skopiowano!' : 'Kopiuj Link', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _copyShareLink(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResonXQrPatternPainter extends CustomPainter {
  final int dataSeed;
  _ResonXQrPatternPainter({required this.dataSeed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const int matrixSize = 21;
    final double cellSize = size.width / matrixSize;
    final random = Random(dataSeed);

    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        final isTopLeftCorner = (r < 7 && c < 7);
        final isTopRightCorner = (r < 7 && c >= matrixSize - 7);
        final isBottomLeftCorner = (r >= matrixSize - 7 && c < 7);

        if (isTopLeftCorner || isTopRightCorner || isBottomLeftCorner) {
          final localR = isBottomLeftCorner ? r - (matrixSize - 7) : r;
          final localC = isTopRightCorner ? c - (matrixSize - 7) : c;

          if (localR == 0 || localR == 6 || localC == 0 || localC == 6 || (localR >= 2 && localR <= 4 && localC >= 2 && localC <= 4)) {
            canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize), paint);
          }
        } else {
          if (random.nextDouble() > 0.48) {
            canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize - 0.5, cellSize - 0.5), paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ResonXQrPatternPainter oldDelegate) => oldDelegate.dataSeed != dataSeed;
}