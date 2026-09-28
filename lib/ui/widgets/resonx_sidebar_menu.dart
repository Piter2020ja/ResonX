import 'package:flutter/material.dart';
import 'resonx_welcome_setup_dialog.dart';

class ResonXSidebarMenu extends StatelessWidget {
  const ResonXSidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      color: const Color(0xFF141414),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.black, size: 26),
                ),
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () {},
                  tooltip: 'Strona Główna',
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.equalizer, color: Colors.white70),
                  onPressed: () {},
                  tooltip: 'Equalizer & DSP',
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.folder_shared, color: Colors.white70),
                  onPressed: () {},
                  tooltip: 'Lokalne Pliki Windows',
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.bar_chart, color: Colors.white70),
                  onPressed: () {},
                  tooltip: 'ResonX Wrapped / Statystyki',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white60),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ResonXWelcomeSetupDialog(),
                    );
                  },
                  tooltip: 'Informacje / Setup / Changelog',
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white60),
                  onPressed: () {},
                  tooltip: 'Ustawienia',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}