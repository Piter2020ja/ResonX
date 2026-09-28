import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/equalizer_service.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXColors.deepGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EqualizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqualizerService>();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Korektor Dźwięku 10-Band EQ',
                  style: TextStyle(
                    color: ResonXColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: eq.isEnabled,
                  activeColor: ResonXColors.cyberJade,
                  onChanged: (val) => eq.toggleEnabled(val),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return Column(
                    children: [
                      Text(
                        eq.bandGains[index].toStringAsFixed(0),
                        style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 10),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: eq.bandGains[index],
                            min: -12.0,
                            max: 12.0,
                            activeColor: ResonXColors.cyberJade,
                            onChanged: eq.isEnabled ? (val) => eq.setBandGain(index, val) : null,
                          ),
                        ),
                      ),
                      Text(
                        EqualizerService.bandFrequencies[index],
                        style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 9),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}