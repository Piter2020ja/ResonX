import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/api_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/downloader_service.dart';
import '../widgets/mini_player.dart';
import 'settings_screen.dart';
import '../../services/database_service.dart';

class ResonXPalette {
  static const Color background = Color(0xFF090A0F);
  static const Color surfaceSidebar = Color(0xFF0D0E15);
  static const Color surfaceCard = Color(0xFF131520);
  static const Color surfaceCardHover = Color(0xFF1C1F30);
  static const Color surfaceSearchBar = Color(0xFF12141D);

  static const Color neonCyan = Color(0xFF00F2FE);
  static const Color neonPurple = Color(0xFF9B51E0);
  static const Color neonMint = Color(0xFF00E676);
  static const Color neonCoral = Color(0xFFFF5252);
  static const Color neonAmber = Color(0xFFFFB300);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color textDim = Color(0xFF535868);

  static const Color borderLight = Color(0xFF1F2333);
  static const Color borderGlow = Color(0x3300F2FE);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _trackListScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();

  String _searchQuery = '';
  String _selectedCategory = 'Polski Rap / Trap';
  String _selectedNav = 'catalog'; // 'favorites', 'downloads', 'playlists', 'catalog'

  bool _isDiscordRpcEnabled = true;
  bool _isLoadingNetworkTracks = false;
  Timer? _searchDebounceTimer;

  late AnimationController _glowPulseController;
  late Animation<double> _glowAnimation;

  // Aktywne utwory sieciowe pobrane z ApiService
  List<Track> _onlineFetchedTracks = [];

  // Ustawienia korektora DSP
  String _activeEqPreset = 'Hip-Hop Punch';
  final Map<String, double> _equalizerBands = {
    '32Hz': 5.0,
    '64Hz': 4.2,
    '125Hz': 2.5,
    '250Hz': 0.0,
    '500Hz': -1.2,
    '1kHz': 1.5,
    '2kHz': 2.8,
    '4kHz': 3.6,
    '8kHz': 4.2,
    '16kHz': 5.0,
  };

  // Pobrane utwory offline w cache
  final Set<String> _offlineDownloadedIds = <String>{};

  // Playlisty użytkownika
  final List<String> _userPlaylists = [
    'Ulubione Trap 2026',
    'Nocny Drill Katowice',
    'Samochodowe Bass',
    'Avi / Klasyki',
  ];

  // Logi systemowe dla Developer & CEO Panel
  final List<String> _devLogs = [
    '[WMF Pipeline] Initialized with DirectSound / MediaEngine backend',
    '[AudioDecoder] AAC/M4A hardware acceleration: ENABLED',
    '[Network] Multi-source Aggregator (Spotify/Apple/YT/SoundCloud): READY',
    '[Auth Cloud] Session initialized (Piter2020ja) - Token verified',
  ];

  bool _isAuthenticated = true;
  String _authProvider = 'Discord (piter2020ja)';

  final List<String> _categories = [
    'Polski Rap / Trap',
    'Polski Drill',
    'Avi / Louis Villain',
    'Malik Montana',
    'PRO8L3M',
    'Bedoes 2115',
    'Kizo / MTS',
    'Oki / 47',
    'Szpaku / GUGU',
    'Gibbs / Dopehouse',
    'Kukon',
    'Sobel',
    'Quebonafide',
    'Taconafide',
    'Otsochodzi',
    'White 2115',
    'Chivas',
    'Żabson',
    'Białas / SBM',
    'Kinny Zimmer',
    'Guzior',
    'Pezet',
    'Paluch',
    'Słoń / WSRH',
    'ReTo',
    'Smolasty',
    'KęKę',
    'Mata',
    'Young Igi',
    'Kaz Bałagane',
  ];

  @override
  void initState() {
    super.initState();

    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.30, end: 0.95).animate(
      CurvedAnimation(
        parent: _glowPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _searchController.addListener(_onSearchInputChanged);

    // Załaduj od razu prawdziwe utwory z sieci dla domyślnego katalogu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeNetworkSearch('Avi');
    });
  }

  void _onSearchInputChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchQuery = query;
      });
      if (query.isNotEmpty) {
        _executeNetworkSearch(query);
      } else {
        _executeNetworkSearch(_selectedCategory.split('/')[0].trim());
      }
    });
  }

  Future<void> _executeNetworkSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoadingNetworkTracks = true;
    });

    try {
      debugPrint('[ResonX Search Engine] Wyszukiwanie prawdziwych utworów dla: "$query"');
      final fetched = await ApiService.instance.searchTracks(
        query,
        includeYouTube: true,
        includeSoundCloud: true,
        targetResultsCount: 45,
      );

      if (mounted) {
        setState(() {
          _onlineFetchedTracks = fetched;
          _isLoadingNetworkTracks = false;
        });
      }
    } catch (e) {
      debugPrint('[ResonX Search Engine] Błąd pobierania utworów: $e');
      if (mounted) {
        setState(() {
          _isLoadingNetworkTracks = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _glowPulseController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _trackListScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  bool _isItemDownloaded(Track track) {
    return _offlineDownloadedIds.contains(track.id) ||
        (track.localPath != null && track.localPath!.isNotEmpty);
  }

  List<Track> _getVisibleTracks(AudioPlayerService playerService) {
  if (_selectedNav == 'favorites') {
    return DatabaseService.instance.favoriteTracks;
  } else if (_selectedNav == 'downloads') {
    return DatabaseService.instance.offlineTracks;
  } else if (_selectedNav == 'playlists') {
    final allTracks = <Track>[];
    for (final pl in DatabaseService.instance.playlists) {
      allTracks.addAll(pl.tracks);
    }
    return allTracks;
  }
  return _onlineFetchedTracks;
}

  void _onCategorySelected(String category) {
    setState(() {
      _selectedNav = 'catalog';
      _selectedCategory = category;
      _searchController.clear();
      _searchQuery = '';
    });

    final searchKeyword = category.split('/')[0].trim();
    _executeNetworkSearch(searchKeyword);
  }

  void _onNavSelected(String navId) {
    setState(() {
      _selectedNav = navId;
    });
  }

  // DIALOG WYMUSZONEGO LOGOWANIA (GOOGLE / DISCORD AUTH GATE)
  void _showAuthGateModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: ResonXPalette.neonCyan, width: 1.5),
            ),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(26, 22),
                        painter: ResonXLogoPainter(glowFactor: 1.0),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'RESONX CLOUD AUTH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Wymagana autoryzacja konta, aby korzystać z nielimitowanego streamingu HQ FLAC/M4A, pobierania offline oraz synchronizacji chmury.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isAuthenticated = true;
                        _authProvider = 'Discord (piter2020ja)';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pomyślnie zalogowano przez Discord OAuth2!')),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF5865F2).withOpacity(0.35), blurRadius: 12),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.discord, color: Colors.white, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Kontynuuj z kontem Discord',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isAuthenticated = true;
                        _authProvider = 'Google (piotr.kulwicki@resonx.cloud)';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zalogowano przez Google Account!')),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: ResonXPalette.surfaceSearchBar,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ResonXPalette.borderLight),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.g_mobiledata_rounded, color: ResonXPalette.neonCyan, size: 30),
                          SizedBox(width: 8),
                          Text(
                            'Zaloguj z kontem Google',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ROZBUDOWANY DEWELOPER & CEO PANEL
  void _showDevAdminConsole(BuildContext context) {
    final customUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: ResonXPalette.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: ResonXPalette.neonCyan, width: 1.5),
                ),
                child: Container(
                  width: 640,
                  height: 590,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.terminal, color: ResonXPalette.neonCyan, size: 24),
                          const SizedBox(width: 10),
                          const Text(
                            'ResonX Developer & CEO Master Console',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: ResonXPalette.textDim, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 140,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ResonXPalette.borderLight),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _devLogs.map((l) {
                              return Text(
                                l,
                                style: const TextStyle(
                                  color: ResonXPalette.neonMint,
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Narzędzia sprzętowe silnika audio & CDN:',
                        style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.refresh, color: ResonXPalette.neonCyan, size: 16),
                            label: const Text('Restart WMF Audio Buffer', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              context.read<AudioPlayerService>().player.stop();
                              setDialogState(() {
                                _devLogs.add('[Manual Action] WMF Player stop() & flush buffer OK');
                              });
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.cleaning_services, color: ResonXPalette.neonMint, size: 16),
                            label: const Text('Wyczyść pamięć podręczną API', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              ApiService.instance.purgeAllCache();
                              setDialogState(() {
                                _devLogs.add('[Cache Flush] Cała pamięć podręczna API wyczyszczona.');
                              });
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.lock_reset, color: ResonXPalette.neonCoral, size: 16),
                            label: const Text('Wymuś wylogowanie (Auth Gate)', style: TextStyle(color: ResonXPalette.neonCoral, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _isAuthenticated = false);
                              _showAuthGateModal(context);
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.verified, color: ResonXPalette.neonAmber, size: 16),
                            label: const Text('Status VIP Lifetime: AKTYWNY', style: TextStyle(color: ResonXPalette.neonAmber, fontSize: 12)),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Direct Stream Injector (przetestuj dowolny link MP3/AAC):',
                        style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customUrlController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Wklej bezpośredni URL strumienia audio...',
                                hintStyle: const TextStyle(color: ResonXPalette.textDim, fontSize: 12),
                                isDense: true,
                                filled: true,
                                fillColor: ResonXPalette.surfaceSearchBar,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                            onPressed: () {
                              final text = customUrlController.text.trim();
                              if (text.isNotEmpty) {
                                final p = context.read<AudioPlayerService>();
                                p.player.setUrl(text);
                                p.player.play();
                                setDialogState(() {
                                  _devLogs.add('[Injector] Wstrzyknięto niestandardowy strumień: $text');
                                });
                              }
                            },
                            child: const Text('Odtwórz', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // DIALOG PROFILU UŻYTKOWNIKA
  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ResonXPalette.borderLight, width: 1.5),
            ),
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [ResonXPalette.neonCyan, ResonXPalette.neonPurple],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ResonXPalette.neonCyan.withOpacity(0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Piotr Kulwicki (Piter2020ja)',
                              style: TextStyle(
                                color: ResonXPalette.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _authProvider,
                              style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: ResonXPalette.borderLight, height: 28),
                  _buildProfileStatRow(Icons.headphones, 'Czas streamingu audio', '4 820 min'),
                  _buildProfileStatRow(Icons.favorite, 'Zapisane ulubione', '${context.read<AudioPlayerService>().favoriteTrackIds.length} utworów'),
                  _buildProfileStatRow(Icons.download_done, 'Pobrana biblioteka offline', '${_offlineDownloadedIds.length} utworów'),
                  _buildProfileStatRow(Icons.audio_file, 'Format wyjściowy', 'Lossless 48kHz DirectSound'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.logout, color: ResonXPalette.neonCoral, size: 18),
                        label: const Text('Wyloguj', style: TextStyle(color: ResonXPalette.neonCoral)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _isAuthenticated = false);
                          _showAuthGateModal(context);
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Zamknij', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileStatRow(IconData icon, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ResonXPalette.neonCyan),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // MODAL KOREKTORA DSP EQUALIZER
  void _showDspEqualizerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ResonXPalette.neonCyan, width: 1.2),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 480,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: ResonXPalette.neonCyan, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'ResonX Ultra DSP Equalizer (10-Band Parametric)',
                        style: TextStyle(color: ResonXPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        dropdownColor: ResonXPalette.surfaceCardHover,
                        value: _activeEqPreset,
                        underline: const SizedBox(),
                        style: const TextStyle(color: ResonXPalette.neonMint, fontWeight: FontWeight.bold),
                        items: ['Flat Studio', 'Hip-Hop Punch', 'Bass Boost', 'Crisp Vocals', 'Electronic Drive'].map((p) {
                          return DropdownMenuItem(value: p, child: Text(p));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              _activeEqPreset = val;
                              if (val == 'Bass Boost') {
                                _equalizerBands['32Hz'] = 7.0;
                                _equalizerBands['64Hz'] = 6.0;
                                _equalizerBands['125Hz'] = 4.0;
                              } else if (val == 'Flat Studio') {
                                _equalizerBands.updateAll((key, value) => 0.0);
                              } else if (val == 'Crisp Vocals') {
                                _equalizerBands['1kHz'] = 3.5;
                                _equalizerBands['2kHz'] = 4.5;
                                _equalizerBands['4kHz'] = 3.0;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _equalizerBands.entries.map((entry) {
                        return Column(
                          children: [
                            Text('${entry.value > 0 ? '+' : ''}${entry.value.toStringAsFixed(1)}dB', style: const TextStyle(color: ResonXPalette.textDim, fontSize: 10)),
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: ResonXPalette.neonCyan,
                                    inactiveTrackColor: ResonXPalette.surfaceSearchBar,
                                    thumbColor: ResonXPalette.neonMint,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  ),
                                  child: Slider(
                                    min: -12.0,
                                    max: 12.0,
                                    value: entry.value,
                                    onChanged: (v) {
                                      setModalState(() {
                                        _equalizerBands[entry.key] = v;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Text(entry.key, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kompensacja przesterowań (Preamp Anti-Clipping): AKTYWNA', style: TextStyle(color: ResonXPalette.textDim, fontSize: 12)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Zastosuj korekcję DSP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // DIALOG NASTROJU (MOOD MATRIX)
  void _showMoodMatrixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ResonXPalette.borderLight)),
            title: const Row(
              children: [
                Icon(Icons.mood, color: ResonXPalette.neonMint),
                SizedBox(width: 10),
                Text('Wybierz Nastrojowy Matrix', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMoodTile('Nocny Chill & Samochód', 'Ciemny bas, spokojne melodie', Icons.nightlife, Colors.indigoAccent),
                _buildMoodTile('Agresywny Drill / Trening', 'Maksymalna energia, szybkie tempo 140+ BPM', Icons.flash_on, ResonXPalette.neonCoral),
                _buildMoodTile('Głęboka Koncentracja & Kodowanie', 'Melodyjny hip-hop instrumental / trap wave', Icons.code, ResonXPalette.neonCyan),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodTile(String title, String subtitle, IconData icon, Color col) {
    return ListTile(
      leading: Icon(icon, color: col),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: ResonXPalette.textDim, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktywowano profil nastroju: $title')));
      },
    );
  }

  // BEZPIECZNY MODAL TEKSTU UTWORU (BEZ BŁĘDU SETSTATE DURING BUILD)
  void _showLyricsModal(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ResonXPalette.neonMint, width: 1),
      ),
      builder: (ctx) {
        return FutureBuilder<List<ResonXLrcLine>>(
          future: ApiService.instance.fetchSynchronizedLyrics(track),
          builder: (context, snapshot) {
            final lyrics = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Container(
              height: 520,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lyrics, color: ResonXPalette.neonMint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${track.title} - ${track.artist}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: ResonXPalette.textDim), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(color: ResonXPalette.borderLight),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: ResonXPalette.neonMint),
                          )
                        : (lyrics.isEmpty
                            ? const Center(
                                child: Text('Brak zsynchronizowanego tekstu dla tego utworu.', style: TextStyle(color: ResonXPalette.textDim)),
                              )
                            : ListView.builder(
                                itemCount: lyrics.length,
                                itemBuilder: (context, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      lyrics[i].text,
                                      style: TextStyle(
                                        color: i == 0 ? ResonXPalette.neonMint : Colors.white70,
                                        fontSize: i == 0 ? 16 : 14.5,
                                        fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // MODAL OPCJI UTWORU
  void _showTrackOptionsModal(
    BuildContext context,
    Track track,
    AudioPlayerService playerService,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: ResonXPalette.borderLight, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      track.coverUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: ResonXPalette.surfaceCardHover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1),
                        Text(track.artist, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 13), maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: ResonXPalette.borderLight, height: 24),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: ResonXPalette.neonCyan),
                title: const Text('Odtwórz jako następny w kolejce', style: TextStyle(color: Colors.white)),
                onTap: () {
                  playerService.insertNext(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dodano "${track.title}" na początek kolejki!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music, color: ResonXPalette.textSecondary),
                title: const Text('Dodaj na koniec kolejki', style: TextStyle(color: Colors.white)),
                onTap: () {
                  playerService.addToQueue(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dodano "${track.title}" na koniec kolejki!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: ResonXPalette.neonMint),
                title: Text(
                  _isItemDownloaded(track) ? 'Pobrano (Dostępne w trybie offline)' : 'Pobierz utwór do pamięci offline',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _offlineDownloadedIds.add(track.id);
                  });
                  DownloaderService.instance.downloadTrack(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rozpoczęto pobieranie "${track.title}" w jakości HQ!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined, color: ResonXPalette.neonAmber),
                title: const Text('Pokaż tekst utworu (Synchronized Lyrics)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLyricsModal(context, track);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<AudioPlayerService>();
    final displayTracks = _getVisibleTracks(playerService);

    return Scaffold(
      backgroundColor: ResonXPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildResonXHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(playerService),
                  Container(width: 1, color: ResonXPalette.borderLight),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBarSection(),
                        _buildCatalogHeaderSection(displayTracks.length),
                        Expanded(
                          child: _isLoadingNetworkTracks
                              ? const Center(
                                  child: CircularProgressIndicator(color: ResonXPalette.neonMint),
                                )
                              : _buildTrackListView(displayTracks, playerService),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildResonXHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: ResonXPalette.surfaceSidebar,
        border: Border(bottom: BorderSide(color: ResonXPalette.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(22, 18),
                painter: ResonXLogoPainter(glowFactor: _glowAnimation.value),
              ),
              const SizedBox(width: 10),
              const Text(
                'RESONX',
                style: TextStyle(
                  color: ResonXPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ResonXPalette.neonMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ResonXPalette.neonMint.withOpacity(0.35), width: 1),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    color: ResonXPalette.neonMint,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.discord,
                size: 19,
                color: _isDiscordRpcEnabled ? const Color(0xFF5865F2) : ResonXPalette.textDim,
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: _isDiscordRpcEnabled,
                  activeColor: ResonXPalette.neonMint,
                  activeTrackColor: ResonXPalette.neonMint.withOpacity(0.3),
                  inactiveThumbColor: ResonXPalette.textDim,
                  inactiveTrackColor: ResonXPalette.borderLight,
                  onChanged: (val) {
                    setState(() => _isDiscordRpcEnabled = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _buildHeaderIconButton(
            icon: Icons.mood_outlined,
            tooltip: 'Tryb nastroju / Mood Matrix',
            onTap: () => _showMoodMatrixDialog(context),
          ),
          _buildHeaderIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Korektor dźwięku (DSP Equalizer)',
            onTap: () => _showDspEqualizerModal(context),
          ),
          _buildHeaderIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Ustawienia odtwarzacza',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _buildHeaderIconButton(
            icon: Icons.terminal_rounded,
            tooltip: 'Konsola deweloperska (Admin / CEO)',
            onTap: () => _showDevAdminConsole(context),
          ),
          _buildHeaderIconButton(
            icon: Icons.account_circle_outlined,
            tooltip: 'Profil użytkownika',
            onTap: () => _showProfileDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: ResonXPalette.surfaceCardHover,
        child: Container(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: ResonXPalette.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSidebar(AudioPlayerService playerService) {
    return Container(
      width: 215,
      color: ResonXPalette.surfaceSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'BIBLIOTEKA',
              style: TextStyle(
                color: ResonXPalette.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSidebarNavItem(
            icon: Icons.favorite,
            iconColor: ResonXPalette.neonCoral,
            title: 'Ulubione Utwory',
            isSelected: _selectedNav == 'favorites',
            badgeCount: playerService.favoriteTrackIds.length,
            onTap: () => _onNavSelected('favorites'),
          ),
          _buildSidebarNavItem(
            icon: Icons.check_circle,
            iconColor: ResonXPalette.neonMint,
            title: 'Pobrane Bez Sieci',
            isSelected: _selectedNav == 'downloads',
            badgeCount: _offlineDownloadedIds.length,
            onTap: () => _onNavSelected('downloads'),
          ),
          _buildSidebarNavItem(
            icon: Icons.queue_music_rounded,
            iconColor: ResonXPalette.neonCyan,
            title: 'Moje Playlisty',
            isSelected: _selectedNav == 'playlists',
            badgeCount: _userPlaylists.length,
            onTap: () => _onNavSelected('playlists'),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'KATALOGI (${_categories.length})',
              style: const TextStyle(
                color: ResonXPalette.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              controller: _sidebarScrollController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedNav == 'catalog' && _selectedCategory == cat;
                return _buildSidebarCategoryItem(
                  title: cat,
                  isSelected: isSelected,
                  onTap: () => _onCategorySelected(cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isSelected,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: ResonXPalette.surfaceCardHover,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? ResonXPalette.neonCyan.withOpacity(0.08) : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? ResonXPalette.neonCyan : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? ResonXPalette.neonCyan : iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? ResonXPalette.textPrimary : ResonXPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Text(
                '$badgeCount',
                style: const TextStyle(color: ResonXPalette.textDim, fontSize: 11, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCategoryItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: ResonXPalette.surfaceCardHover,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? ResonXPalette.neonCyan.withOpacity(0.08) : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? ResonXPalette.neonCyan : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 14,
              color: isSelected ? ResonXPalette.neonMint : ResonXPalette.textDim,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? ResonXPalette.neonMint : ResonXPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: ResonXPalette.surfaceSearchBar,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _searchFocusNode.hasFocus ? ResonXPalette.neonCyan.withOpacity(0.6) : ResonXPalette.borderLight,
            width: 1.2,
          ),
          boxShadow: _searchFocusNode.hasFocus
              ? [BoxShadow(color: ResonXPalette.neonCyan.withOpacity(0.12), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, size: 20, color: _searchFocusNode.hasFocus ? ResonXPalette.neonCyan : ResonXPalette.textDim),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: ResonXPalette.textPrimary, fontSize: 14),
                cursorColor: ResonXPalette.neonCyan,
                decoration: const InputDecoration(
                  hintText: 'Wyszukaj utwór, artystę lub wklej nazwę albumu...',
                  hintStyle: TextStyle(color: ResonXPalette.textDim, fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: ResonXPalette.textDim),
                onPressed: () {
                  _searchController.clear();
                  _onSearchInputChanged();
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogHeaderSection(int totalItems) {
    String title = _selectedCategory;
    if (_searchQuery.isNotEmpty) {
      title = 'Wyniki dla: "$_searchQuery"';
    } else if (_selectedNav == 'favorites') {
      title = 'Ulubione Utwory';
    } else if (_selectedNav == 'downloads') {
      title = 'Pobrane Bez Sieci (Offline)';
    } else if (_selectedNav == 'playlists') {
      title = 'Moje Playlisty';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: ResonXPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            '$totalItems pozycji',
            style: const TextStyle(color: ResonXPalette.textDim, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListView(
    List<Track> tracks,
    AudioPlayerService playerService,
  ) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text('Brak utworów do wyświetlenia.', style: TextStyle(color: ResonXPalette.textDim)),
      );
    }

    return ListView.separated(
      controller: _trackListScrollController,
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = playerService.currentTrack?.id == track.id;
        final isPlayingThis = isCurrent && playerService.isPlaying;
        final isFav = playerService.favoriteTrackIds.contains(track.id);
        final isDownloaded = _isItemDownloaded(track);

        return _ResonXTrackListTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isPlayingThis,
          isFavorite: isFav,
          isDownloaded: isDownloaded,
          onTap: () async {
            if (isCurrent) {
              playerService.togglePlayPause();
            } else {
              // Rozwiązanie bezpośredniego linku strumienia przed odtworzeniem
              try {
                final directUrl = await ApiService.instance.resolveAudioStreamUrl(track);
                final resolvedTrack = Track(
                  id: track.id,
                  title: track.title,
                  artist: track.artist,
                  album: track.album,
                  audioUrl: directUrl.isNotEmpty ? directUrl : track.audioUrl,
                  coverUrl: track.coverUrl,
                  durationSeconds: track.durationSeconds,
                  localPath: track.localPath,
                );
                playerService.setQueue(tracks, startIndex: index);
                playerService.playTrack(resolvedTrack);
              } catch (_) {
                playerService.setQueue(tracks, startIndex: index);
              }
            }
          },
          onToggleFavorite: () => playerService.toggleFavorite(track),
          onDownloadTap: () {
            setState(() {
              if (_offlineDownloadedIds.contains(track.id)) {
                _offlineDownloadedIds.remove(track.id);
              } else {
                _offlineDownloadedIds.add(track.id);
              }
            });
            DownloaderService.instance.downloadTrack(track);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isItemDownloaded(track) ? 'Pobrano "${track.title}" do trybu offline.' : 'Usunięto z pamięci offline.')),
            );
          },
          onMoreTap: () => _showTrackOptionsModal(context, track, playerService),
        );
      },
    );
  }
}

class _ResonXTrackListTile extends StatefulWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isFavorite;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDownloadTap;
  final VoidCallback onMoreTap;

  const _ResonXTrackListTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isFavorite,
    required this.isDownloaded,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDownloadTap,
    required this.onMoreTap,
  });

  @override
  State<_ResonXTrackListTile> createState() => _ResonXTrackListTileState();
}

class _ResonXTrackListTileState extends State<_ResonXTrackListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isCurrent
        ? ResonXPalette.neonCyan.withOpacity(0.06)
        : (_isHovered ? ResonXPalette.surfaceCardHover : Colors.transparent);

    final borderColor = widget.isCurrent ? ResonXPalette.neonCyan.withOpacity(0.35) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      widget.track.coverUrl,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 42, height: 42, color: ResonXPalette.surfaceCard),
                    ),
                  ),
                  if (widget.isCurrent || _isHovered)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: ResonXPalette.neonMint,
                        size: 24,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      style: TextStyle(
                        color: widget.isCurrent ? ResonXPalette.neonMint : ResonXPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: widget.isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(widget.track.artist, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 12.5)),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: ResonXPalette.textDim, fontSize: 10)),
                        const SizedBox(width: 6),
                        const Text('HQ Audio (M4A)', style: TextStyle(color: ResonXPalette.textDim, fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                  size: 19,
                  color: widget.isDownloaded ? ResonXPalette.neonMint : (_isHovered ? ResonXPalette.textSecondary : ResonXPalette.textDim),
                ),
                tooltip: widget.isDownloaded ? 'Pobrano offline' : 'Pobierz offline',
                onPressed: widget.onDownloadTap,
              ),
              IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 19,
                  color: widget.isFavorite ? ResonXPalette.neonCoral : (_isHovered ? ResonXPalette.textSecondary : ResonXPalette.textDim),
                ),
                onPressed: widget.onToggleFavorite,
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, size: 19, color: _isHovered ? ResonXPalette.textSecondary : ResonXPalette.textDim),
                onPressed: widget.onMoreTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResonXLogoPainter extends CustomPainter {
  final double glowFactor;

  ResonXLogoPainter({required this.glowFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ResonXPalette.neonMint
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = ResonXPalette.neonMint.withOpacity(0.4 * glowFactor)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;

    final heights = [0.4, 0.9, 0.55, 1.0, 0.45];
    final step = size.width / (heights.length - 1);

    for (var i = 0; i < heights.length; i++) {
      final x = i * step;
      final h = size.height * heights[i];
      final y1 = (size.height - h) / 2;
      final y2 = y1 + h;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), glowPaint);
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ResonXLogoPainter oldDelegate) => oldDelegate.glowFactor != glowFactor;
}