import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/dsp_audio_engine.dart';

class DspEqualizerPanel extends StatelessWidget {
  const DspEqualizerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspAudioEngine>(
      builder: (context, dsp, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.equalizer, color: Color(0xFF1DB954)),
                      SizedBox(width: 8),
                      Text(
                        'ResonX DSP & 10-Band Equalizer',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Switch(
                    value: dsp.isEqualizerEnabled,
                    activeColor: const Color(0xFF1DB954),
                    onChanged: (val) => dsp.toggleEqualizer(val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Presets bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DspAudioEngine.presets.keys.map((presetName) {
                    final isSelected = dsp.currentPreset == presetName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(presetName),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1DB954),
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => dsp.applyPreset(presetName),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              // Slidery 10 pasm
              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    final frequencies = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1k', '2k', '4k', '8k', '16k'];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${dsp.eqGains[index].toStringAsFixed(1)}dB',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: dsp.eqGains[index],
                              min: -15.0,
                              max: 15.0,
                              activeColor: const Color(0xFF1DB954),
                              inactiveColor: Colors.white10,
                              onChanged: (val) => dsp.setEqualizerBand(index, val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          frequencies[index],
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const Divider(color: Colors.white12, height: 32),
              // Dodatkowe efekty DSP (Reverb & 3D Audio)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Audio 3D / 8D Rotation', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Switch(
                    value: dsp.is3dAudioEnabled,
                    activeColor: const Color(0xFF1DB954),
                    onChanged: (val) {
                      // Przekazanie domyślnego odtwarzacza
                      dsp.toggle3dAudio(val, null as dynamic);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reverb Studio (Pogłos)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  DropdownButton<String>(
                    value: dsp.reverbMode,
                    dropdownColor: const Color(0xFF222222),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: ['Studio', 'Arena', 'Church', 'Concert Hall', 'Techno Club']
                        .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) dsp.toggleReverb(true, val);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}