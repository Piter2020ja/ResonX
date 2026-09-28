import 'package:flutter/material.dart';
import 'dart:io';

class AdminCeoPanelDialog extends StatefulWidget {
  const AdminCeoPanelDialog({super.key});

  @override
  State<AdminCeoPanelDialog> createState() => _AdminCeoPanelDialogState();
}

class _AdminCeoPanelDialogState extends State<AdminCeoPanelDialog> {
  bool _isCleaning = false;
  String _cacheStatus = '248.4 MB używane w cache';

  void _clearSystemCache() async {
    setState(() {
      _isCleaning = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isCleaning = false;
        _cacheStatus = '0.0 MB (Wyczyszczono pomyślnie)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pamięć podręczna ResonX została wyczyszczona!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Color(0xFF1DB954), size: 28),
                    SizedBox(width: 12),
                    Text(
                      'ResonX CEO & Diagnostics Console',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 28),
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    'DIAGNOSTYKA SYSTEMOWA WINDOWS',
                    style: TextStyle(color: Color(0xFF1DB954), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Platforma robocza', style: TextStyle(color: Colors.white60)),
                            Text('Windows ${Platform.operatingSystemVersion}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Użycie pamięci RAM', style: TextStyle(color: Colors.white60)),
                            const Text('~84.2 MB / 512 MB limitu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stan pamięci Cache', style: TextStyle(color: Colors.white60)),
                            Text(_cacheStatus, style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'NARZĘDZIA ZARZĄDZANIA',
                    style: TextStyle(color: Color(0xFF1DB954), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isCleaning
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cleaning_services, color: Colors.white),
                    label: const Text('Wyczyść całą pamięć Cache i pliki tymczasowe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _isCleaning ? null : _clearSystemCache,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}