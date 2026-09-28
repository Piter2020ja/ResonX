import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/track.dart';
import '../../services/smart_features_service.dart';

class ShareDropSheet extends StatelessWidget {
  final Track track;

  const ShareDropSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final smart = SmartFeaturesService.instance;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: ResonXColors.surfaceBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ResonXColors.cardBorder, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: ResonXColors.cyberJade, size: 28),
              const SizedBox(width: 10),
              const Text(
                'ResonX Drop & Social Share',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ResonXColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: ResonXColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ResonXColors.cyberJade.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code, size: 120, color: Colors.black),
                  const SizedBox(height: 4),
                  Text(
                    'RESONX-${track.id.hashCode.abs().toString().padLeft(6, '0')}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Zeskanuj kod QR innym telefonem, aby natychmiast odtworzyć "${track.title}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ResonXColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.groups, color: ResonXColors.neonCyan),
                  label: const Text('Start Party Mode', style: TextStyle(color: ResonXColors.textPrimary)),
                  onPressed: () {
                    smart.startPartyMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Utworzono pokój Party Mode: ${smart.partyRoomCode}')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResonXColors.cyberJade,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopiuj Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Skopiowano unikalny odnośnik utworu!')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}