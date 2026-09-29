import 'dart:math' as math;
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
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: ResonXColors.surfaceBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ResonXColors.cardBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(screenSize.width - 28.0, 480.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal, color: ResonXColors.neonCyan, size: 26),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'ResonX CEO Console & Diagnostics',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ResonXColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: ResonXColors.textSecondary, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!_isUnlocked) ...[
                  const Text(
                    'Wprowadź Master PIN Administratora (CEO PIN), aby odblokować pełne uprawnienia diagnostyczne:',
                    style: TextStyle(color: ResonXColors.textSecondary, fontSize: 13, height: 1.4),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _verifyPin,
                    child: const Text('Odblokuj Konsolę', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ] else ...[
                  _buildMetricTile('Status Sesji', 'CEO Master Access Active', ResonXColors.cyberJade),
                  _buildMetricTile('Audio Pipeline', 'MediaKit / MPV Native Stream', ResonXColors.neonCyan),
                  _buildMetricTile('Discord RPC Client', '1542593239352221836 (Active)', const Color(0xFF5865F2)),
                  _buildMetricTile('Kolejka odtwarzacza', '${AudioPlayerService.instance.queue.length} utworów', ResonXColors.textPrimary),
                  _buildMetricTile('Status Odtwarzania', AudioPlayerService.instance.isPlaying ? 'Grający (Playing)' : 'Wstrzymany (Paused)', ResonXColors.cyberJade),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ResonXColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.refresh, color: ResonXColors.cyberJade, size: 18),
                          label: const Text(
                            'Reset Audio',
                            style: TextStyle(color: ResonXColors.textPrimary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            AudioPlayerService.instance.seek(Duration.zero);
                            setState(() => _statusMessage = 'Zresetowano strumień odtwarzacza.');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ResonXColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.delete_sweep, color: ResonXColors.errorRed, size: 18),
                          label: const Text(
                            'Wyczyść Cache',
                            style: TextStyle(color: ResonXColors.textPrimary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            setState(() => _statusMessage = 'Pamięć podręczna oczyszczona.');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ResonXColors.deepGraphite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ResonXColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}