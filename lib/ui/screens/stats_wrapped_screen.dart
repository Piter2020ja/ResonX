import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/stats_and_achievements_service.dart';
import '../../services/audio_player_service.dart';

class StatsWrappedScreen extends StatelessWidget {
  const StatsWrappedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0E14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'ResonX Wrapped & Raport Audio',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF00F2FE)),
            tooltip: 'Udostępnij swój raport Wrapped',
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                text: 'Mój roczny raport ResonX Wrapped: Słucham w najwyższej jakości Lossless 48kHz! Dołącz do ResonX 🎧✨',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Skopiowano podsumowanie Wrapped do schowka!'),
                  backgroundColor: Color(0xFF11131C),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<StatsAndAchievementsService>(
        builder: (context, stats, child) {
          final totalMins = stats.totalListeningMinutes;
          final hours = (totalMins / 60).toStringAsFixed(1);
          final playerService = context.watch<AudioPlayerService>();
          final favoritesCount = playerService.favoriteTrackIds.length;

          // Określenie rangi użytkownika na podstawie czasu
          String userRankTitle = 'Początkujący Słuchacz';
          Color rankColor = const Color(0xFF8E95A5);
          if (totalMins > 1000) {
            userRankTitle = 'Audiophile Master & Trapper';
            rankColor = const Color(0xFF00E676);
          } else if (totalMins > 300) {
            userRankTitle = 'Koneser Brzmienia HQ';
            rankColor = const Color(0xFF00F2FE);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GŁÓWNA KARTA RAPORTU (STYLP SPOTIFY WRAPPED)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D231A), Color(0xFF11131C), Color(0xFF1A0E2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TWÓJ ROCZNY RAPORT AUDIO',
                            style: TextStyle(color: Color(0xFF00E676), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.8),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: rankColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              userRankTitle,
                              style: TextStyle(color: rankColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$hours godzin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'spędzonych na aktywne słuchanie muzyki w bezstratnej jakości DirectSound w ResonX.',
                        style: TextStyle(color: Color(0xFF8E95A5), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFF1E2232)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn('Ulubione utwory', '$favoritesCount'),
                          _buildStatColumn('Aktywna kolejka', '${playerService.queue.length}'),
                          _buildStatColumn('Format strumienia', 'Lossless 48kHz'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'SYSTEM ODZNAK I OSIĄGNIĘĆ',
                  style: TextStyle(color: Color(0xFF00F2FE), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                ),
                const SizedBox(height: 14),
                // LISTA OSIĄGNIĘĆ
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.achievements.length,
                  itemBuilder: (context, index) {
                    final item = stats.achievements[index];
                    final isUnlocked = item['unlocked'] as bool;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11131C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUnlocked ? const Color(0xFF00E676).withValues(alpha: 0.4) : const Color(0xFF1E2232),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isUnlocked ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF161924),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                item['icon'] as String,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    color: isUnlocked ? Colors.white : const Color(0xFF8E95A5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(color: Color(0xFF555B6E), fontSize: 11.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                            color: isUnlocked ? const Color(0xFF00E676) : const Color(0xFF555B6E),
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF555B6E), fontSize: 11)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}