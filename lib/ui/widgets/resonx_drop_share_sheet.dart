import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/track.dart';

class ResonXDropShareSheet extends StatelessWidget {
  final Track track;
  const ResonXDropShareSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final shareUrl = 'https://resonx.local/share?id=${track.id}&title=${Uri.encodeComponent(track.title)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code, color: Color(0xFF1DB954)),
              SizedBox(width: 8),
              Text(
                'ResonX Drop (Share via Local QR)',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Symulacja kodu QR
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_2, size: 140, color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${track.title} - ${track.artist}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.copy, color: Colors.black),
            label: const Text('Kopiuj link strumienia LAN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareUrl));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Skopiowano link ResonX Drop do schowka!')),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}