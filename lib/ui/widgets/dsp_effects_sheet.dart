import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/dsp_processor_service.dart';

class DspEffectsSheet extends StatelessWidget {
  const DspEffectsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final dsp = Provider.of<DspProcessorService>(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: ResonXColors.surfaceBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ResonXColors.cardBorder, width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: ResonXColors.neonCyan, size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Przetwarzanie Akustyki & DSP',
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
            SwitchListTile(
              title: const Text('Sub-Bass Cutoff (Filtr 20Hz)', style: TextStyle(color: ResonXColors.textPrimary)),
              subtitle: const Text('Odcięcie poddźwięków w celu eliminacji przesterowań membran', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
              value: dsp.subBassCut,
              activeColor: ResonXColors.cyberJade,
              onChanged: (val) => dsp.toggleSubBassCut(val),
            ),
            SwitchListTile(
              title: const Text('Konwersja Stereo do Mono', style: TextStyle(color: ResonXColors.textPrimary)),
              subtitle: const Text('Miksowanie kanałów (optymalne do słuchania na 1 słuchawce)', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
              value: dsp.monoConversion,
              activeColor: ResonXColors.cyberJade,
              onChanged: (val) => dsp.toggleMono(val),
            ),
            SwitchListTile(
              title: const Text('Dźwięk Przestrzenny 8D Audio', style: TextStyle(color: ResonXColors.textPrimary)),
              subtitle: const Text('Binauralna symulacja krążenia źródła dźwięku wokół głowy', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
              value: dsp.spatial8DEnabled,
              activeColor: ResonXColors.neonCyan,
              onChanged: (val) => dsp.toggleSpatial8D(val),
            ),
            const SizedBox(height: 12),
            const Text('Balans Sceny Muzycznej (Stereo Pan)', style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
            Slider(
              value: dsp.stereoPan,
              min: -1.0,
              max: 1.0,
              divisions: 20,
              activeColor: ResonXColors.cyberJade,
              inactiveColor: ResonXColors.cardBorder,
              onChanged: (val) => dsp.setStereoPan(val),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lewy (L)', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
                Text(
                  dsp.stereoPan == 0 ? 'Środek' : (dsp.stereoPan < 0 ? 'L: ${(dsp.stereoPan.abs() * 100).toInt()}%' : 'P: ${(dsp.stereoPan * 100).toInt()}%'),
                  style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Text('Prawy (R)', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Symulacja Przestrzeni Pogłosu (Reverb)', style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildReverbChip('Brak', ReverbPreset.off, dsp),
                _buildReverbChip('Pokój', ReverbPreset.smallRoom, dsp),
                _buildReverbChip('Studio', ReverbPreset.studio, dsp),
                _buildReverbChip('Sala Koncertowa', ReverbPreset.concertHall, dsp),
                _buildReverbChip('Jaskinia', ReverbPreset.cave, dsp),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Kompensacja Opóźnienia Bluetooth (Sync Offset)', style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
            Slider(
              value: dsp.bluetoothSyncOffsetMs.toDouble(),
              min: -500.0,
              max: 500.0,
              divisions: 40,
              activeColor: ResonXColors.neonCyan,
              inactiveColor: ResonXColors.cardBorder,
              onChanged: (val) => dsp.setBluetoothOffset(val.toInt()),
            ),
            Center(
              child: Text(
                '${dsp.bluetoothSyncOffsetMs > 0 ? '+' : ''}${dsp.bluetoothSyncOffsetMs} ms',
                style: const TextStyle(color: ResonXColors.neonCyan, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReverbChip(String label, ReverbPreset preset, DspProcessorService dsp) {
    final isSelected = dsp.reverb == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: ResonXColors.neonCyan,
      labelStyle: TextStyle(color: isSelected ? Colors.black : ResonXColors.textPrimary, fontSize: 12),
      onSelected: (_) => dsp.setReverb(preset),
    );
  }
}