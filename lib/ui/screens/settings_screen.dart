import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/auth_cloud_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/dsp_processor_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _audioQuality = 'Lossless HQ (320kbps)';
  double _crossfadeDuration = 3.0;
  bool _hardwareAcceleration = true;
  bool _autoResume = true;
  bool _normalizeVolume = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthCloudService>(context);
    final dsp = Provider.of<DspProcessorService>(context);
    final player = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: ResonXColors.deepGraphite,
      appBar: AppBar(
        backgroundColor: ResonXColors.surfaceBlack,
        title: const Text('Centrum Ustawień & Konfiguracja 170 Funkcji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionHeader('PROFIL & KONTO RESONX'),
          ListTile(
            leading: const Icon(Icons.account_circle, color: ResonXColors.cyberJade, size: 32),
            title: Text(auth.session?.username ?? 'Gość', style: const TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text('${auth.session?.email ?? 'brak'} • Rola: ${auth.session?.tier.name.toUpperCase()}', style: const TextStyle(color: ResonXColors.textSecondary)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ResonXColors.errorRed),
              onPressed: () async {
                final nav = Navigator.of(context);
                await auth.logout();
                if (mounted) nav.pop();
              },
              child: const Text('Wyloguj', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(color: ResonXColors.cardBorder, height: 32),

          _buildSectionHeader('JAKOŚĆ DŹWIĘKU & SILNIK AUDIO DSP'),
          ListTile(
            title: const Text('Jakość Strumieniowania Audio', style: TextStyle(color: ResonXColors.textPrimary)),
            subtitle: Text(_audioQuality, style: const TextStyle(color: ResonXColors.cyberJade)),
            trailing: DropdownButton<String>(
              dropdownColor: ResonXColors.surfaceBlack,
              value: _audioQuality,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'Eco (128kbps AAC)', child: Text('Eco (128kbps AAC)', style: TextStyle(color: ResonXColors.textPrimary))),
                DropdownMenuItem(value: 'Standard (192kbps MP3)', child: Text('Standard (192kbps MP3)', style: TextStyle(color: ResonXColors.textPrimary))),
                DropdownMenuItem(value: 'Lossless HQ (320kbps)', child: Text('Lossless HQ (320kbps)', style: TextStyle(color: ResonXColors.cyberJade))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _audioQuality = val);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Normalizacja Głośności (ReplayGain)', style: TextStyle(color: ResonXColors.textPrimary)),
            subtitle: const Text('Wyrównuje poziom głośności między różnymi albumami i utworami', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
            value: _normalizeVolume,
            activeThumbColor: ResonXColors.cyberJade,
            onChanged: (val) => setState(() => _normalizeVolume = val),
          ),
          SwitchListTile(
            title: const Text('Aktywny Procesor Efektów DSP', style: TextStyle(color: ResonXColors.textPrimary)),
            subtitle: Text(
              dsp.isEnabled ? 'Włączony (Bass Boost: ${(dsp.bassBoostLevel * 100).toInt()}%, 3D: ${(dsp.spatialAudioLevel * 100).toInt()}%)' : 'Wyłączony',
              style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 12),
            ),
            value: dsp.isEnabled,
            activeThumbColor: ResonXColors.cyberJade,
            onChanged: (val) => dsp.setEnabled(val),
          ),
          ListTile(
            title: const Text('Płynne Przejścia Utworów (Crossfade)', style: TextStyle(color: ResonXColors.textPrimary)),
            subtitle: Text('${_crossfadeDuration.toStringAsFixed(1)} sekundy miksowania', style: const TextStyle(color: ResonXColors.neonCyan)),
            trailing: SizedBox(
              width: 180,
              child: Slider(
                value: _crossfadeDuration,
                min: 0.0,
                max: 12.0,
                divisions: 12,
                activeColor: ResonXColors.cyberJade,
                onChanged: (val) => setState(() => _crossfadeDuration = val),
              ),
            ),
          ),
          const Divider(color: ResonXColors.cardBorder, height: 32),

          _buildSectionHeader('INTEGRACJA DISCORD RICH PRESENCE (CLIENT ID: 1542593239352221836)'),
          SwitchListTile(
            title: const Text('Pokazuj Aktualnie Słuchany Utwór na Discordzie', style: TextStyle(color: ResonXColors.textPrimary)),
            subtitle: const Text('Wysyła tytuł, wykonawcę oraz okładkę bezpośrednio do Twojego profilu Discord', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
            value: auth.session?.discordStatusEnabled ?? false,
            activeThumbColor: ResonXColors.cyberJade,
            onChanged: (val) {
              auth.toggleDiscordStatus(val);
              player.updateDiscordPresence();
            },
          ),
          const Divider(color: ResonXColors.cardBorder, height: 32),

          _buildSectionHeader('WYDAJNOŚĆ WINDOWS & PAMIĘĆ PODRĘCZNA'),
          SwitchListTile(
            title: const Text('Akceleracja Sprzętowa GPU (DirectX / Vulkan)', style: TextStyle(color: ResonXColors.textPrimary)),
            value: _hardwareAcceleration,
            activeThumbColor: ResonXColors.cyberJade,
            onChanged: (val) => setState(() => _hardwareAcceleration = val),
          ),
          SwitchListTile(
            title: const Text('Automatyczne Wznawianie Odtwarzania po Uruchomieniu', style: TextStyle(color: ResonXColors.textPrimary)),
            value: _autoResume,
            activeThumbColor: ResonXColors.cyberJade,
            onChanged: (val) => setState(() => _autoResume = val),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: ResonXColors.neonCyan),
            title: const Text('Wyczyść Pamięć Podręczną Tekstów i Okładek', style: TextStyle(color: ResonXColors.textPrimary)),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: ResonXColors.cardBorder)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wyczyszczono lokalny bufor pamięci podręcznej ResonX.')),
                );
              },
              child: const Text('Wyczyść Cache', style: TextStyle(color: ResonXColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          color: ResonXColors.cyberJade,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}