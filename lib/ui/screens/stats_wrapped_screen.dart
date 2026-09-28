import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/stats_and_achievements_service.dart';

class StatsWrappedScreen extends StatelessWidget {
  const StatsWrappedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ResonX Wrapped & Statystyki Odsłuchu',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<StatsAndAchievementsService>(
        builder: (context, stats, child) {
          final hours = (stats.totalListeningMinutes / 60).toStringAsFixed(1);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DB954), Color(0xFF121212)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TWÓJ ROCZNY RAPORT AUDIO',
                        style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$hours godzin',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'spędzonych na słuchaniu muzyki w wysokiej rozdzielczości HQ w ResonX.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'SYSTEM ODZNAK I OSIĄGNIĘĆ',
                  style: TextStyle(color: Color(0xFF1DB954), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.achievements.length,
                  itemBuilder: (context, index) {
                    final item = stats.achievements[index];
                    final isUnlocked = item['unlocked'] as bool;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isUnlocked ? const Color(0xFF1DB954).withOpacity(0.4) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isUnlocked ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                item['icon'] as String,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    color: isUnlocked ? Colors.white : Colors.white60,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isUnlocked ? Icons.check_circle : Icons.lock_outline,
                            color: isUnlocked ? const Color(0xFF1DB954) : Colors.white30,
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
}