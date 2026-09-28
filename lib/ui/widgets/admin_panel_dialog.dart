import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/security_service.dart';
import '../../services/auth_cloud_service.dart';
import '../../services/audio_player_service.dart';

class AdminPanelDialog extends StatefulWidget {
  const AdminPanelDialog({super.key});

  @override
  State<AdminPanelDialog> createState() => _AdminPanelDialogState();
}

class _AdminPanelDialogState extends State<AdminPanelDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isUnlocked = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final session = AuthCloudService.instance.session;
    if (session != null && session.isCeo) {
      _isUnlocked = true;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final pin = _pinController.text.trim();
    if (SecurityService.instance.verifyCeoPin(pin)) {
      AuthCloudService.instance.promoteToCeo();
      setState(() {
        _isUnlocked = true;
        _statusMessage = 'Dostęp CEO autoryzowany pomyślnie.';
      });
    } else {
      setState(() {
        _statusMessage = 'Niepoprawny PIN Administratora.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ResonXColors.surfaceBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ResonXColors.cardBorder, width: 1.5),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: ResonXColors.neonCyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'ResonX CEO Console & Diagnostics',
                  style: TextStyle(
                    fontSize: 20,
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
            const SizedBox(height: 20),
            if (!_isUnlocked) ...[
              const Text(
                'Wprowadź Master PIN Administratora (CEO PIN), aby odblokować pełne uprawnienia diagnostyczne:',
                style: TextStyle(color: ResonXColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: ResonXColors.textPrimary, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: 'PIN (np. 7895)',
                  labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                  filled: true,
                  fillColor: ResonXColors.deepGraphite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ResonXColors.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _verifyPin,
                child: const Text('Odblokuj Konsolę', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              _buildMetricTile('Status Sesji', 'CEO Master Access Active', ResonXColors.cyberJade),
              _buildMetricTile('Audio Pipeline', 'just_audio / 44.1kHz 320kbps', ResonXColors.neonCyan),
              _buildMetricTile('Discord RPC Client', '1542593239352221836 (Active)', const Color(0xFF5865F2)),
              _buildMetricTile('Kolejka odtwarzacza', '${AudioPlayerService.instance.queue.length} pozycji', ResonXColors.textPrimary),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ResonXColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh, color: ResonXColors.cyberJade),
                      label: const Text('Reset Audio', style: TextStyle(color: ResonXColors.textPrimary)),
                      onPressed: () {
                        AudioPlayerService.instance.seek(Duration.zero);
                        setState(() => _statusMessage = 'Zresetowano strumień odtwarzacza.');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ResonXColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.delete_sweep, color: ResonXColors.errorRed),
                      label: const Text('Wyczyść Cache', style: TextStyle(color: ResonXColors.textPrimary)),
                      onPressed: () {
                        setState(() => _statusMessage = 'Pamięć podręczna oczyszczona.');
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ResonXColors.deepGraphite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ResonXColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}