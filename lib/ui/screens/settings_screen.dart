import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/auth_cloud_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/dsp_processor_service.dart';
import '../../services/equalizer_service.dart';
import '../../services/api_service.dart';
import '../../services/downloader_service.dart';
import '../../services/github_update_service.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _audioQuality = 'Lossless HQ (320kbps / FLAC)';
  double _crossfadeDuration = 3.0;
  double _bufferLatencySeconds = 3.0;
  bool _hardwareAcceleration = true;
  bool _autoResume = true;
  bool _normalizeVolume = true;
  bool _autoSkipSilence = true;
  bool _realtimeAudioPriority = true;

  @override
  void initState() {
    super.initState();
    final player = AudioPlayerService.instance;
    _crossfadeDuration = player.crossfadeSeconds;
    GithubUpdateService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthCloudService>(context);
    final dsp = Provider.of<DspProcessorService>(context);
    final player = Provider.of<AudioPlayerService>(context);
    final eq = Provider.of<EqualizerService>(context);
    final battery = Provider.of<BatterySaverService>(context);
    final updater = Provider.of<GithubUpdateService>(context);

    final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      backgroundColor: ResonXColors.deepGraphite,
      appBar: AppBar(
        backgroundColor: ResonXColors.surfaceBlack,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Centrum Ustawień & Konfiguracja',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
        children: [
          _buildSectionHeader('PROFIL & KONTO RESONX'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ResonXColors.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: ResonXColors.cyberJade,
                  child: Icon(Icons.person, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.session?.username ?? 'Gość (Tryb Lokalny)',
                        style: const TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        auth.session?.email.isNotEmpty == true ? auth.session!.email : 'Zabezpieczona sesja offline',
                        style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: auth.isAuthenticated ? ResonXColors.errorRed : ResonXColors.cyberJade,
                    foregroundColor: auth.isAuthenticated ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await auth.logout();
                    if (mounted) nav.pop();
                  },
                  child: Text(auth.isAuthenticated ? 'Wyloguj' : 'Gość Beta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('SYSTEM & AKTUALIZACJE MULTIPLATFORMOWE'),
          Container(
            decoration: BoxDecoration(
              color: ResonXColors.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_rounded, color: ResonXColors.neonCyan),
                  title: const Text('Aktualizacje ResonX (GitHub OTA)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: Text(
                    'Aktualna wersja: v${updater.currentVersion} (${Platform.operatingSystem.toUpperCase()})',
                    style: const TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5),
                  ),
                  trailing: updater.isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ResonXColors.cyberJade),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ResonXColors.cyberJade,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            updater.checkForUpdates(showNoUpdateDialog: true, context: context);
                          },
                          child: const Text('Sprawdź', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('JAKOŚĆ DŹWIĘKU & SILNIK AUDIO DSP'),
          Container(
            decoration: BoxDecoration(
              color: ResonXColors.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Jakość Strumieniowania Audio', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: Text(_audioQuality, style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    dropdownColor: ResonXColors.surfaceBlack,
                    value: _audioQuality,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'Eco (128kbps AAC)', child: Text('Eco (128kbps AAC)')),
                      DropdownMenuItem(value: 'Standard (192kbps MP3)', child: Text('Standard (192kbps MP3)')),
                      DropdownMenuItem(value: 'Lossless HQ (320kbps / FLAC)', child: Text('Lossless HQ (FLAC)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _audioQuality = val);
                    },
                  ),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Normalizacja Głośności (ReplayGain)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: const Text('Wyrównuje poziom głośności między różnymi albumami i utworami', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                  value: _normalizeVolume,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => setState(() => _normalizeVolume = val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Aktywny Procesor Efektów DSP', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: Text(
                    dsp.isEnabled ? 'Włączony (Bass Boost: ${(dsp.bassBoostLevel * 100).toInt()}%, 3D: ${(dsp.spatialAudioLevel * 100).toInt()}%)' : 'Wyłączony',
                    style: const TextStyle(color: ResonXColors.cyberJade, fontSize: 11.5),
                  ),
                  value: dsp.isEnabled,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => dsp.setEnabled(val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Inteligentne Pomijanie Ciszy i Intro', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: const Text('Automatycznie przycina martwe początki nagrań z SoundCloud', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                  value: _autoSkipSilence,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => setState(() => _autoSkipSilence = val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Płynne Przejścia Utworów (Crossfade)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                          Text('${_crossfadeDuration.toStringAsFixed(1)}s', style: const TextStyle(color: ResonXColors.neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Slider(
                        value: _crossfadeDuration,
                        min: 0.0,
                        max: 12.0,
                        divisions: 12,
                        activeColor: ResonXColors.cyberJade,
                        inactiveColor: ResonXColors.deepGraphite,
                        onChanged: (val) {
                          setState(() => _crossfadeDuration = val);
                          player.setCrossfadeDuration(val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('GRAFICZNY KOREKTOR DŹWIĘKU (EQ)'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ResonXColors.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Korektor Częstotliwości', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Switch(
                      value: eq.isEnabled,
                      activeThumbColor: ResonXColors.cyberJade,
                      onChanged: (val) => eq.setEnabled(val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('Flat', () => eq.setPreset([0, 0, 0, 0, 0])),
                      const SizedBox(width: 8),
                      _buildPresetChip('Bass Boost', () => eq.setPreset([6, 4, 0, 2, 5])),
                      const SizedBox(width: 8),
                      _buildPresetChip('Electronic', () => eq.setPreset([5, 3, -2, 4, 6])),
                      const SizedBox(width: 8),
                      _buildPresetChip('Rock', () => eq.setPreset([4, 2, -1, 3, 4])),
                      const SizedBox(width: 8),
                      _buildPresetChip('Vocal', () => eq.setPreset([-2, 2, 5, 3, -1])),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEqSlider('60 Hz', eq.band60Hz, (v) => eq.setBand(0, v)),
                    _buildEqSlider('230 Hz', eq.band230Hz, (v) => eq.setBand(1, v)),
                    _buildEqSlider('910 Hz', eq.band910Hz, (v) => eq.setBand(2, v)),
                    _buildEqSlider('4 kHz', eq.band4kHz, (v) => eq.setBand(3, v)),
                    _buildEqSlider('14 kHz', eq.band14kHz, (v) => eq.setBand(4, v)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isDesktop) ...[
            _buildSectionHeader('INTEGRACJA DISCORD RICH PRESENCE'),
            Container(
              decoration: BoxDecoration(
                color: ResonXColors.surfaceBlack,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ResonXColors.cardBorder),
              ),
              child: SwitchListTile(
                title: const Text('Pokazuj Utwór na Discordzie', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                subtitle: const Text('Wysyła tytuł, wykonawcę oraz okładkę do profilu Discord (Client ID: 1542593239)', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                value: auth.session?.discordStatusEnabled ?? false,
                activeThumbColor: ResonXColors.cyberJade,
                onChanged: (val) {
                  auth.toggleDiscordStatus(val);
                  player.updateDiscordPresence();
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader('WYDAJNOŚĆ URZĄDZENIA & PAMIĘĆ PODRĘCZNA'),
          Container(
            decoration: BoxDecoration(
              color: ResonXColors.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ResonXColors.cardBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Inteligentne Oszczędzanie Baterii (Low Power UI)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: const Text('Ogranicza animacje wizualizatora i obciążenie procesora w tle', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                  value: battery.isBatterySaverEnabled,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) {
                    battery.setBatterySaver(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? 'Włączono tryb oszczędzania energii.' : 'Wyłączono tryb oszczędzania energii.'),
                        backgroundColor: ResonXColors.surfaceBlack,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Akceleracja Sprzętowa Renderowania', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  value: _hardwareAcceleration,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => setState(() => _hardwareAcceleration = val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Wysoki Priorytet Wątków Audio (Real-Time)', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: const Text('Zapobiega przerywaniu dźwięku przy obciążeniu procesora', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                  value: _realtimeAudioPriority,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => setState(() => _realtimeAudioPriority = val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                SwitchListTile(
                  title: const Text('Automatyczne Wznawianie Odtwarzania', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  value: _autoResume,
                  activeThumbColor: ResonXColors.cyberJade,
                  onChanged: (val) => setState(() => _autoResume = val),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bufor Strumienia Sieciowego', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                          Text('${_bufferLatencySeconds.toInt()} sekund', style: const TextStyle(color: ResonXColors.cyberJade, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Slider(
                        value: _bufferLatencySeconds,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        activeColor: ResonXColors.cyberJade,
                        inactiveColor: ResonXColors.deepGraphite,
                        onChanged: (val) => setState(() => _bufferLatencySeconds = val),
                      ),
                    ],
                  ),
                ),
                const Divider(color: ResonXColors.cardBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: ResonXColors.neonCyan),
                  title: const Text('Wyczyść Cache Tekstów i Okładek', style: TextStyle(color: ResonXColors.textPrimary, fontSize: 13.5)),
                  subtitle: const Text('Usuwa tymczasowe pliki podręczne z pamięci', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11.5)),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: ResonXColors.cardBorder)),
                    onPressed: () async {
                      ApiService.instance.purgeAllCache();
                      await DownloaderService.instance.cleanTemporaryArtifacts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pomyślnie wyczyszczono pamięć podręczną ResonX!')),
                        );
                      }
                    },
                    child: const Text('Wyczyść', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: ResonXColors.deepGraphite,
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      onPressed: onTap,
    );
  }

  Widget _buildEqSlider(String title, double value, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Text('${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}dB', style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 4),
        SizedBox(
          height: 120,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: -12.0,
              max: 12.0,
              divisions: 24,
              activeColor: ResonXColors.cyberJade,
              inactiveColor: ResonXColors.deepGraphite,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: ResonXColors.cyberJade,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}