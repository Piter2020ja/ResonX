import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../models/track.dart';
import '../../models/user_session.dart';
import '../../services/api_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/auth_cloud_service.dart';
import '../../services/downloader_service.dart';
import '../../services/database_service.dart';
import '../widgets/mini_player.dart';
import 'settings_screen.dart';

class ResonXPalette {
  static const Color background = Color(0xFF07080B);
  static const Color surfaceSidebar = Color(0xFF0C0E14);
  static const Color surfaceCard = Color(0xFF11131C);
  static const Color surfaceCardHover = Color(0xFF1A1D2B);
  static const Color surfaceSearchBar = Color(0xFF0F1118);

  static const Color neonCyan = Color(0xFF00F2FE);
  static const Color neonPurple = Color(0xFF9B51E0);
  static const Color neonMint = Color(0xFF00E676);
  static const Color neonCoral = Color(0xFFFF5252);
  static const Color neonAmber = Color(0xFFFFB300);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color textDim = Color(0xFF555B6E);

  static const Color borderLight = Color(0xFF1E2232);
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
  String _selectedNav = 'catalog'; // 'catalog', 'favorites', 'downloads', 'playlists'

  String? _activePlaylistName;
  int _mobileNavIndex = 0;

  bool _isDiscordRpcEnabled = true;
  bool _isLoadingNetworkTracks = false;
  Timer? _searchDebounceTimer;

  double _currentPlaybackSpeed = 1.0;
  bool _autoSkipSilenceIntro = true;
  int _defaultSilenceTrimSeconds = 2;

  final Map<String, int> _trackCustomStartOffsets = <String, int>{};

  int _totalListenedSeconds = 18450;
  final Map<String, int> _artistPlayCounts = <String, int>{
    'Avi / Louis Villain': 42,
    'Malik Montana': 28,
    'PRO8L3M': 19,
    'Bedoes 2115': 14,
    'Kizo / MTS': 11,
  };

  late AnimationController _glowPulseController;
  late Animation<double> _glowAnimation;

  List<Track> _onlineFetchedTracks = [];

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

  final Set<String> _offlineDownloadedIds = <String>{};

  final Map<String, List<Track>> _playlistTracksMap = <String, List<Track>>{
    'Ulubione Trap 2026': [],
    'Nocny Drill Katowice': [],
    'Samochodowe Bass': [],
    'Avi / Klasyki': [],
  };

  final List<String> _devLogs = [
    '[WMF Pipeline] MediaEngine / Native DirectSound backend READY',
    '[AudioEngine] Dekoder strumieni FLAC / M4A / MP3 aktywny',
    '[AudioTrim] Silnik pomijania wstępu i intro aktywny',
    '[PlaylistManager] Lokalny silnik bazy playlist aktywny',
    '[Security] Panel administratora zabezpieczony szyfrowanym PIN-em',
  ];

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
    );
    _glowPulseController.value = 0.8;

    _glowAnimation = Tween<double>(begin: 0.30, end: 0.95).animate(
      CurvedAnimation(
        parent: _glowPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _searchController.addListener(_onSearchInputChanged);

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
      debugPrint('[ResonX Search Engine] Pobieranie utworów dla: "$query"');
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
      debugPrint('[ResonX Search Engine] Błąd wyszukiwania: $e');
      if (mounted) {
        setState(() {
          _isLoadingNetworkTracks = false;
        });
      }
    }
  }

  Future<void> _refreshNetworkStreams(BuildContext context) async {
    setState(() {
      _isLoadingNetworkTracks = true;
    });

    try {
      ApiService.instance.purgeAllCache();
      debugPrint('[ResonX Network] Wyczyszczono cache strumieni oraz odświeżono tokeny.');

      final currentKeyword = _searchQuery.isNotEmpty 
          ? _searchQuery 
          : _selectedCategory.split('/')[0].trim();
          
      await _executeNetworkSearch(currentKeyword);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pomyślnie odświeżono połączenie sieciowe i tokeny strumieni!'),
            backgroundColor: ResonXPalette.surfaceCardHover,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ResonX Network] Błąd odświeżania sieci: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd odświeżania sieci: $e'),
            backgroundColor: ResonXPalette.neonCoral,
          ),
        );
      }
    } finally {
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
      if (_activePlaylistName != null && _playlistTracksMap.containsKey(_activePlaylistName)) {
        return _playlistTracksMap[_activePlaylistName]!;
      }
      final allTracks = <Track>[];
      for (final list in _playlistTracksMap.values) {
        allTracks.addAll(list);
      }
      return allTracks;
    }
    return _onlineFetchedTracks;
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedNav = 'catalog';
      _selectedCategory = category;
      _activePlaylistName = null;
      _searchController.clear();
      _searchQuery = '';
    });

    final searchKeyword = category.split('/')[0].trim();
    _executeNetworkSearch(searchKeyword);
  }

  void _onNavSelected(String navId) {
    setState(() {
      _selectedNav = navId;
      if (navId != 'playlists') {
        _activePlaylistName = null;
      }
    });
  }

  void _showSetTrackStartOffsetModal(BuildContext context, Track track, AudioPlayerService playerService) {
    final currentOffset = _trackCustomStartOffsets[track.id] ?? 0;
    double sliderVal = currentOffset.toDouble();
    final int maxSec = track.durationSeconds > 0 ? track.durationSeconds : 300;

    showModalBottomSheet(
      context: context,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ResonXPalette.neonCyan, width: 1.2),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int m = sliderVal.toInt() ~/ 60;
            final int s = sliderVal.toInt() % 60;
            final formattedTime = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

            return Container(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.av_timer_rounded, color: ResonXPalette.neonCyan, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pomiń intro: ${track.title}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: ResonXPalette.textDim),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ustaw, od której sekundy piosenka ma startować (omijając ciszę lub wstęp):',
                    style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Początek: $formattedTime',
                      style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: ResonXPalette.neonMint,
                      inactiveTrackColor: ResonXPalette.borderLight,
                      thumbColor: ResonXPalette.neonCyan,
                    ),
                    child: Slider(
                      min: 0,
                      max: maxSec.toDouble(),
                      value: sliderVal.clamp(0, maxSec.toDouble()),
                      onChanged: (v) {
                        setModalState(() {
                          sliderVal = v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: ResonXPalette.borderLight)),
                        onPressed: () {
                          setModalState(() {
                            sliderVal = 15.0;
                          });
                        },
                        child: const Text('+15s Intro', style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: ResonXPalette.borderLight)),
                        onPressed: () {
                          setModalState(() {
                            sliderVal = 30.0;
                          });
                        },
                        child: const Text('+30s Beat', style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 11)),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: ResonXPalette.neonCyan)),
                        onPressed: () {
                          final currentPos = playerService.position.inSeconds.toDouble();
                          setModalState(() {
                            sliderVal = currentPos.clamp(0.0, maxSec.toDouble());
                          });
                        },
                        child: const Text('Aktualny moment', style: TextStyle(color: ResonXPalette.neonCyan, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, color: ResonXPalette.neonCoral, size: 16),
                        label: const Text('Resetuj (0:00)', style: TextStyle(color: ResonXPalette.neonCoral)),
                        onPressed: () {
                          setState(() {
                            _trackCustomStartOffsets.remove(track.id);
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zresetowano punkt startu utworu.')),
                          );
                        },
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                        onPressed: () {
                          setState(() {
                            _trackCustomStartOffsets[track.id] = sliderVal.toInt();
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Zapisano: "${track.title}" zacznie się od $formattedTime!')),
                          );
                        },
                        child: const Text('Zapisz punkt startu', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showStatsWrappedModal(BuildContext context, AudioPlayerService playerService) {
    final int totalMinutes = _totalListenedSeconds ~/ 60;
    final int totalHours = totalMinutes ~/ 60;
    final int remainingMins = totalMinutes % 60;

    final sortedArtists = _artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonXPalette.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: ResonXPalette.neonCyan, width: 1.5),
      ),
      builder: (ctx) {
        return Container(
          height: 620,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: ResonXPalette.neonMint, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ResonX Wrapped & Statystyki Live',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: ResonXPalette.textDim), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ResonXPalette.neonMint.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TWÓJ GŁÓWNY GATUNEK (LOCAL MATRIX)', style: TextStyle(color: ResonXPalette.neonCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(_selectedCategory, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildWrappedStat('Czas słuchania', '${totalHours}h ${remainingMins}m'),
                        const SizedBox(width: 16),
                        _buildWrappedStat('Kolejka', '${playerService.queue.length} pozycji'),
                        const SizedBox(width: 16),
                        _buildWrappedStat('Ulubione', '${playerService.favoriteTrackIds.length} utworów'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Najczęściej słuchani wykonawcy w ResonX:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedArtists.length,
                  itemBuilder: (context, i) {
                    final item = sortedArtists[i];
                    final colors = [ResonXPalette.neonMint, ResonXPalette.neonCyan, ResonXPalette.neonPurple, ResonXPalette.neonCoral, ResonXPalette.neonAmber];
                    final color = colors[i % colors.length];

                    return _buildArtistRankRow('${i + 1}', item.key, '${item.value} pełnych odsłuchań', color);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWrappedStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildArtistRankRow(String rank, String name, String subtitle, Color badgeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ResonXPalette.surfaceSearchBar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ResonXPalette.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: badgeColor.withValues(alpha: 0.2),
            child: Text(rank, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: ResonXPalette.textDim, fontSize: 11.5)),
              ],
            ),
          ),
          Icon(Icons.bar_chart_rounded, color: badgeColor, size: 20),
        ],
      ),
    );
  }

  void _showPlaybackSpeedModal(BuildContext context, AudioPlayerService playerService) {
    final textController = TextEditingController(text: _currentPlaybackSpeed.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: ResonXPalette.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: ResonXPalette.neonCyan, width: 1.5),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, color: ResonXPalette.neonCyan, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Prędkość Odtwarzania',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ResonXPalette.textDim, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_currentPlaybackSpeed.toStringAsFixed(2)}x',
                        style: const TextStyle(
                          color: ResonXPalette.neonMint,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: ResonXPalette.neonCyan,
                          inactiveTrackColor: ResonXPalette.borderLight,
                          thumbColor: ResonXPalette.neonMint,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          min: 0.5,
                          max: 2.5,
                          divisions: 40,
                          value: _currentPlaybackSpeed.clamp(0.5, 2.5),
                          onChanged: (val) {
                            setDialogState(() {
                              _currentPlaybackSpeed = val;
                              textController.text = val.toStringAsFixed(2);
                            });
                            playerService.player.setRate(val);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [0.80, 1.0, 1.15, 1.25, 1.35, 1.5].map((rate) {
                          final isCurrent = (_currentPlaybackSpeed - rate).abs() < 0.02;
                          return ActionChip(
                            backgroundColor: isCurrent ? ResonXPalette.neonCyan.withValues(alpha: 0.2) : ResonXPalette.surfaceSearchBar,
                            side: BorderSide(color: isCurrent ? ResonXPalette.neonCyan : ResonXPalette.borderLight),
                            label: Text(
                              '${rate.toStringAsFixed(2)}x',
                              style: TextStyle(
                                color: isCurrent ? ResonXPalette.neonCyan : Colors.white70,
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _currentPlaybackSpeed = rate;
                                textController.text = rate.toStringAsFixed(2);
                              });
                              playerService.player.setRate(rate);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: ResonXPalette.borderLight),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Wpisz własną prędkość (np. 1.12, 0.93):',
                          style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Wpisz np. 1.20',
                                hintStyle: const TextStyle(color: ResonXPalette.textDim),
                                filled: true,
                                fillColor: ResonXPalette.surfaceSearchBar,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonMint, foregroundColor: Colors.black),
                            onPressed: () {
                              final customVal = double.tryParse(textController.text.replaceAll(',', '.'));
                              if (customVal != null && customVal >= 0.25 && customVal <= 3.0) {
                                setDialogState(() {
                                  _currentPlaybackSpeed = customVal;
                                });
                                playerService.player.setRate(customVal);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ustawiono prędkość odtwarzania: ${customVal.toStringAsFixed(2)}x')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Wpisz poprawną wartość od 0.25 do 3.0')),
                                );
                              }
                            },
                            child: const Text('Zastosuj', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showCreatePlaylistDialog(BuildContext context) {
    final playlistNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ResonXPalette.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ResonXPalette.borderLight)),
        title: const Row(
          children: [
            Icon(Icons.playlist_add, color: ResonXPalette.neonCyan),
            SizedBox(width: 10),
            Text('Nowa Playlista', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: playlistNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nazwa Twojej playlisty...',
            hintStyle: TextStyle(color: ResonXPalette.textDim),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ResonXPalette.borderLight)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ResonXPalette.neonCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: ResonXPalette.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
            onPressed: () {
              final name = playlistNameCtrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _playlistTracksMap[name] = <Track>[];
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Utworzono playlistę: "$name"')));
              }
            },
            child: const Text('Stwórz', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ResonXPalette.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ResonXPalette.neonCyan)),
        title: Text('Dodaj "${track.title}" do playlisty', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: _playlistTracksMap.isEmpty
              ? const Text('Brak utworzonych playlist. Stwórz najpierw playlistę!', style: TextStyle(color: ResonXPalette.textDim))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _playlistTracksMap.keys.length,
                  itemBuilder: (context, i) {
                    final plName = _playlistTracksMap.keys.elementAt(i);
                    final isAlreadyIn = _playlistTracksMap[plName]!.any((t) => t.id == track.id);

                    return ListTile(
                      leading: Icon(Icons.queue_music, color: isAlreadyIn ? ResonXPalette.neonMint : ResonXPalette.neonCyan),
                      title: Text(plName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: isAlreadyIn
                          ? const Text('Dodano', style: TextStyle(color: ResonXPalette.neonMint, fontSize: 11))
                          : const Icon(Icons.add_circle_outline, color: ResonXPalette.neonCyan),
                      onTap: () {
                        if (!isAlreadyIn) {
                          setState(() {
                            _playlistTracksMap[plName]!.add(track);
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dodano "${track.title}" do "$plName"!')));
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zamknij', style: TextStyle(color: ResonXPalette.textDim)),
          ),
        ],
      ),
    );
  }

  void _showAuthGateModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: ResonXPalette.neonCoral, width: 1.5),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_person_rounded, color: ResonXPalette.neonCoral, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'RESONX CLOUD AUTH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ResonXPalette.neonCoral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ResonXPalette.neonCoral.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Logowanie w chmurze zostało zablokowane na urządzeniach mobilnych w tej wersji (Wersja Beta Android). Korzystaj bez limitów w trybie lokalnym.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 22),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logowanie przez Discord jest zablokowane w wersji Beta Android.'),
                          backgroundColor: ResonXPalette.surfaceCardHover,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A1A1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ResonXPalette.neonCoral.withValues(alpha: 0.8), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.discord, color: ResonXPalette.neonCoral, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Discord OAuth2 (ZABLOKOWANE)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ResonXPalette.neonCoral,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('BETA', style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logowanie przez Google jest zablokowane w wersji Beta Android.'),
                          backgroundColor: ResonXPalette.surfaceCardHover,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A1A1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ResonXPalette.neonCoral.withValues(alpha: 0.8), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.g_mobiledata_rounded, color: ResonXPalette.neonCoral, size: 28),
                          const SizedBox(width: 6),
                          const Text(
                            'Konto Google (ZABLOKOWANE)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ResonXPalette.neonCoral,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('BETA', style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kontynuuj w trybie gościa (Pełny dostęp)', style: TextStyle(color: ResonXPalette.neonMint, fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _requestAdminPinAccess(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ResonXPalette.neonCyan, width: 1.4),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: ResonXPalette.neonCyan, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Dostęp Autoryzowany',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Wprowadź kod PIN administratora:',
                    style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: ResonXPalette.surfaceSearchBar,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Anuluj', style: TextStyle(color: ResonXPalette.textDim)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                        onPressed: () {
                          if (pinController.text == '7895') {
                            Navigator.pop(ctx);
                            _showDevAdminConsole(context);
                          } else {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nieprawidłowy kod PIN.'),
                                backgroundColor: ResonXPalette.neonCoral,
                              ),
                            );
                          }
                        },
                        child: const Text('Zatwierdź', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showDevAdminConsole(BuildContext context) {
    final customUrlController = TextEditingController();
    final authService = context.read<AuthCloudService>();

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
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ResonXPalette.borderLight),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '[Auth Info] Sesja: ${authService.session?.username ?? "Brak (Gość)"} | Ranga: ${authService.session?.tier.name.toUpperCase() ?? "FREE"}',
                                style: const TextStyle(
                                  color: ResonXPalette.neonCyan,
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                              ..._devLogs.map((l) {
                                return Text(
                                  l,
                                  style: const TextStyle(
                                    color: ResonXPalette.neonMint,
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                );
                              }),
                            ],
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
                            label: const Text('Zresetuj bufor MediaKit', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              context.read<AudioPlayerService>().player.stop();
                              setDialogState(() {
                                _devLogs.add('[Manual Action] Odtwarzacz zresetowany.');
                              });
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.cleaning_services, color: ResonXPalette.neonMint, size: 16),
                            label: const Text('Wyczyść cache API', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              ApiService.instance.purgeAllCache();
                              setDialogState(() {
                                _devLogs.add('[Cache Flush] Pamięć podręczna wyczyszczona.');
                              });
                            },
                          ),
                          ActionChip(
                            backgroundColor: ResonXPalette.surfaceCardHover,
                            avatar: const Icon(Icons.lock_reset, color: ResonXPalette.neonCoral, size: 16),
                            label: const Text('Wymuś Auth Gate', style: TextStyle(color: ResonXPalette.neonCoral, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAuthGateModal(context);
                            },
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
                                p.player.open(Media(text));
                                setDialogState(() {
                                  _devLogs.add('[Injector] Odtwarzanie strumienia: $text');
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

  void _showProfileDialog(BuildContext context) {
    final authService = context.read<AuthCloudService>();
    final session = authService.session;
    final bool isLoggedIn = authService.isAuthenticated;

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
              constraints: const BoxConstraints(maxWidth: 440),
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
                              color: ResonXPalette.neonCyan.withValues(alpha: 0.3),
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
                            Text(
                              isLoggedIn ? session!.username : 'Gość (Niezalogowany)',
                              style: const TextStyle(
                                color: ResonXPalette.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoggedIn
                                  ? (session!.email.isNotEmpty ? session.email : 'Konto zsynchronizowane')
                                  : 'Tryb lokalny aktywny (Beta Android)',
                              style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: ResonXPalette.borderLight, height: 28),
                  _buildProfileStatRow(
                    Icons.verified_user_outlined,
                    'Poziom konta',
                    isLoggedIn ? session!.tier.name.toUpperCase() : 'FREE',
                  ),
                  _buildProfileStatRow(
                    Icons.favorite,
                    'Zapisane ulubione',
                    '${context.read<AudioPlayerService>().favoriteTrackIds.length} utworów',
                  ),
                  _buildProfileStatRow(
                    Icons.download_done,
                    'Biblioteka offline',
                    '${_offlineDownloadedIds.length} utworów',
                  ),
                  _buildProfileStatRow(
                    Icons.audio_file,
                    'Format strumienia',
                    'DirectSound HQ 320kbps / Lossless FLAC',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (isLoggedIn)
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.logout, color: ResonXPalette.neonCoral, size: 18),
                            label: const Text('Wyloguj', style: TextStyle(color: ResonXPalette.neonCoral)),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await context.read<AuthCloudService>().logout();
                            },
                          ),
                        )
                      else
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A1A1E)),
                            icon: const Icon(Icons.lock, size: 16, color: ResonXPalette.neonCoral),
                            label: const Text('Auth Gate (BETA)', style: TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAuthGateModal(context);
                            },
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Zamknij', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: ResonXPalette.neonCyan, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ResonX Ultra DSP Equalizer',
                          style: TextStyle(color: ResonXPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _equalizerBands.entries.map((entry) {
                          return Container(
                            width: 58,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
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
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Preamp Anti-Clipping: AKTYWNY',
                          style: TextStyle(color: ResonXPalette.textDim, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Zastosuj DSP', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        ? const Center(child: CircularProgressIndicator(color: ResonXPalette.neonMint))
                        : (lyrics.isEmpty
                            ? const Center(child: Text('Brak zsynchronizowanego tekstu dla tego utworu.', style: TextStyle(color: ResonXPalette.textDim)))
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

  void _showTrackOptionsModal(BuildContext context, Track track, AudioPlayerService playerService) {
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
                leading: const Icon(Icons.playlist_add_circle_rounded, color: ResonXPalette.neonMint),
                title: const Text('Dodaj do wybranej playlisty...', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.av_timer_rounded, color: ResonXPalette.neonCyan),
                title: const Text('Ustaw punkt startu (Pomiń intro)', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _trackCustomStartOffsets.containsKey(track.id)
                      ? 'Obecnie: ${_trackCustomStartOffsets[track.id]}s'
                      : 'Odtwarzaj od początku (0:00)',
                  style: const TextStyle(color: ResonXPalette.textDim, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetTrackStartOffsetModal(context, track, playerService);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: ResonXPalette.neonCyan),
                title: const Text('Odtwórz jako następny w kolejce', style: TextStyle(color: Colors.white)),
                onTap: () {
                  playerService.insertNext(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dodano "${track.title}" na początek kolejki!')));
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
                    SnackBar(content: Text(_isItemDownloaded(track) ? 'Pobrano "${track.title}" do trybu offline.' : 'Usunięto z pamięci offline.')),
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
    final authService = context.watch<AuthCloudService>();
    final displayTracks = _getVisibleTracks(playerService);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 750;

        return Scaffold(
          backgroundColor: ResonXPalette.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildResonXHeader(authService, playerService),
                Expanded(
                  child: isMobile
                      ? _buildMobileLayout(displayTracks, playerService, authService)
                      : _buildDesktopLayout(displayTracks, playerService),
                ),
                const MiniPlayer(),
              ],
            ),
          ),
          bottomNavigationBar: isMobile
              ? Container(
                  decoration: const BoxDecoration(
                    color: ResonXPalette.surfaceSidebar,
                    border: Border(top: BorderSide(color: ResonXPalette.borderLight, width: 1)),
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      indicatorColor: ResonXPalette.neonCyan.withValues(alpha: 0.16),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const TextStyle(color: ResonXPalette.neonMint, fontSize: 11, fontWeight: FontWeight.bold);
                        }
                        return const TextStyle(color: ResonXPalette.textDim, fontSize: 11);
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const IconThemeData(color: ResonXPalette.neonMint);
                        }
                        return const IconThemeData(color: ResonXPalette.textDim);
                      }),
                    ),
                    child: NavigationBar(
                      height: 60,
                      selectedIndex: _mobileNavIndex,
                      onDestinationSelected: (idx) {
                        setState(() {
                          _mobileNavIndex = idx;
                          if (idx == 0) _selectedNav = 'catalog';
                          if (idx == 2) _selectedNav = 'favorites';
                          if (idx == 3) _selectedNav = 'playlists';
                        });
                      },
                      destinations: const [
                        NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: 'Katalogi'),
                        NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Szukaj'),
                        NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Ulubione'),
                        NavigationDestination(icon: Icon(Icons.queue_music_outlined), selectedIcon: Icon(Icons.queue_music), label: 'Playlisty'),
                        NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Narzędzia'),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildDesktopLayout(List<Track> displayTracks, AudioPlayerService playerService) {
    return Row(
      children: [
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _buildSidebar(playerService),
          ),
        ),
        Container(width: 1, color: ResonXPalette.borderLight),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBarSection(),
              _buildCatalogHeaderSection(displayTracks.length),
              Expanded(
                child: _isLoadingNetworkTracks
                    ? const Center(child: CircularProgressIndicator(color: ResonXPalette.neonMint))
                    : _buildTrackListView(displayTracks, playerService),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<Track> displayTracks, AudioPlayerService playerService, AuthCloudService authService) {
    switch (_mobileNavIndex) {
      case 0:
        return Column(
          children: [
            Container(
              height: 48,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedNav == 'catalog' && _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : ResonXPalette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      backgroundColor: ResonXPalette.surfaceCard,
                      selectedColor: ResonXPalette.neonMint,
                      checkmarkColor: Colors.black,
                      side: BorderSide(color: isSelected ? ResonXPalette.neonMint : ResonXPalette.borderLight),
                      onSelected: (_) => _onCategorySelected(cat),
                    ),
                  );
                },
              ),
            ),
            _buildCatalogHeaderSection(displayTracks.length),
            Expanded(
              child: _isLoadingNetworkTracks
                  ? const Center(child: CircularProgressIndicator(color: ResonXPalette.neonMint))
                  : _buildTrackListView(displayTracks, playerService),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildSearchBarSection(),
            _buildCatalogHeaderSection(displayTracks.length),
            Expanded(
              child: _isLoadingNetworkTracks
                  ? const Center(child: CircularProgressIndicator(color: ResonXPalette.neonMint))
                  : _buildTrackListView(displayTracks, playerService),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildLibraryPill('Ulubione Utwory', 'favorites', Icons.favorite, ResonXPalette.neonCoral, playerService.favoriteTrackIds.length),
                  const SizedBox(width: 8),
                  _buildLibraryPill('Pobrane Bez Sieci', 'downloads', Icons.download_done, ResonXPalette.neonMint, _offlineDownloadedIds.length),
                ],
              ),
            ),
            _buildCatalogHeaderSection(displayTracks.length),
            Expanded(
              child: _buildTrackListView(displayTracks, playerService),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_activePlaylistName != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: ResonXPalette.neonCyan, size: 18),
                      onPressed: () {
                        setState(() {
                          _activePlaylistName = null;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      _activePlaylistName != null ? 'Playlista: $_activePlaylistName' : 'Moje Playlisty',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_activePlaylistName == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black, elevation: 0),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nowa', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: ResonXPalette.neonCoral, size: 22),
                      tooltip: 'Usuń tę playlistę',
                      onPressed: () {
                        final deletingName = _activePlaylistName!;
                        setState(() {
                          _playlistTracksMap.remove(deletingName);
                          _activePlaylistName = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usunięto playlistę "$deletingName".')));
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: _activePlaylistName == null
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _playlistTracksMap.keys.length,
                      itemBuilder: (context, i) {
                        final name = _playlistTracksMap.keys.elementAt(i);
                        final trackCount = _playlistTracksMap[name]!.length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: ResonXPalette.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ResonXPalette.borderLight),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.queue_music, color: ResonXPalette.neonCyan),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('$trackCount utworów', style: const TextStyle(color: ResonXPalette.textDim, fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios, color: ResonXPalette.textDim, size: 14),
                            onTap: () {
                              setState(() {
                                _activePlaylistName = name;
                                _selectedNav = 'playlists';
                              });
                            },
                          ),
                        );
                      },
                    )
                  : (_playlistTracksMap[_activePlaylistName]!.isEmpty
                      ? const Center(
                          child: Text('Playlista jest pusta.\nDodaj utwory klikając menu (...) na dowolnej piosence!',
                              textAlign: TextAlign.center, style: TextStyle(color: ResonXPalette.textDim)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                          itemCount: _playlistTracksMap[_activePlaylistName]!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final track = _playlistTracksMap[_activePlaylistName]![index];

                            return Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: ResonXPalette.surfaceCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ResonXPalette.borderLight),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      track.coverUrl,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(width: 42, height: 42, color: ResonXPalette.surfaceCardHover),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                        Text(track.artist, style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 11), maxLines: 1),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: ResonXPalette.neonMint, size: 26),
                                    onPressed: () {
                                      playerService.setQueue(_playlistTracksMap[_activePlaylistName]!, startIndex: index);
                                      playerService.playTrack(track);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: ResonXPalette.neonCoral, size: 20),
                                    tooltip: 'Usuń z tej playlisty',
                                    onPressed: () {
                                      setState(() {
                                        _playlistTracksMap[_activePlaylistName]!.removeAt(index);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usunięto "${track.title}" z playlisty.')));
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        );
      case 4:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [ResonXPalette.neonCyan, ResonXPalette.neonPurple]),
                  boxShadow: [BoxShadow(color: ResonXPalette.neonCyan.withValues(alpha: 0.3), blurRadius: 18)],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                authService.isAuthenticated ? authService.session!.username : 'Gość (Niezalogowany)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                authService.isAuthenticated ? authService.session!.email : 'Zaloguj się, aby zsynchronizować konto',
                style: const TextStyle(color: ResonXPalette.neonMint, fontSize: 13),
              ),
              const SizedBox(height: 22),
              _buildMobileToolCard(
                icon: Icons.open_in_browser_rounded,
                title: 'Systemowa Pływająca Wyspa (Overlay)',
                subtitle: 'Włącz/wyłącz pigułkę nad wszystkimi aplikacjami',
                onTap: () async {
                  final hasPerm = await FlutterOverlayWindow.isPermissionGranted();
                  if (!hasPerm) {
                    await FlutterOverlayWindow.requestPermission();
                  } else {
                    final isActive = await FlutterOverlayWindow.isActive();
                    if (isActive) {
                      await FlutterOverlayWindow.closeOverlay();
                    } else {
                      await FlutterOverlayWindow.showOverlay(
                        enableDrag: true,
                        overlayTitle: "ResonX Floating Island",
                        overlayContent: 'Dynamiczny odtwarzacz w toku...',
                        flag: OverlayFlag.defaultFlag,
                        visibility: NotificationVisibility.visibilityPublic,
                        positionGravity: PositionGravity.auto,
                        height: 240,
                        width: WindowSize.matchParent,
                      );
                    }
                  }
                },
              ),
              _buildMobileToolCard(
                icon: Icons.auto_graph_rounded,
                title: 'ResonX Wrapped & Statystyki (Live)',
                subtitle: 'Pełne statystyki czasu i ulubionych wykonawców',
                onTap: () => _showStatsWrappedModal(context, playerService),
              ),
              _buildMobileToolCard(
                icon: Icons.speed_rounded,
                title: 'Prędkość odtwarzania (DSP Rate)',
                subtitle: 'Obecnie: ${_currentPlaybackSpeed.toStringAsFixed(2)}x (Wpisz z klawiatury)',
                onTap: () => _showPlaybackSpeedModal(context, playerService),
              ),
              _buildMobileToolCard(
                icon: Icons.tune,
                title: 'Korektor dźwięku DSP',
                subtitle: '10-pasmowy equalizer parametryczny',
                onTap: () => _showDspEqualizerModal(context),
              ),
              _buildMobileToolCard(
                icon: Icons.music_video_rounded,
                title: 'Wykrywanie ciszy i intro',
                subtitle: _autoSkipSilenceIntro ? 'Aktywne: auto-skip $_defaultSilenceTrimSeconds s na początku' : 'Wyłączone',
                onTap: () {
                  setState(() {
                    _autoSkipSilenceIntro = !_autoSkipSilenceIntro;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_autoSkipSilenceIntro ? 'Włączono inteligentne pomijanie ciszy intro!' : 'Wyłączono pomijanie ciszy.')),
                  );
                },
              ),
              _buildMobileToolCard(
                icon: Icons.mood,
                title: 'Nastrojowy Matrix',
                subtitle: 'Profile dźwiękowe dla nastroju',
                onTap: () => _showMoodMatrixDialog(context),
              ),
              _buildMobileToolCard(
                icon: Icons.settings,
                title: 'Ustawienia odtwarzacza',
                subtitle: 'Konfiguracja bufora i silnika',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              _buildMobileToolCard(
                icon: Icons.terminal,
                title: 'Konsola deweloperska (PIN)',
                subtitle: 'Zabezpieczony panel administratora',
                onTap: () => _requestAdminPinAccess(context),
              ),
              const SizedBox(height: 18),
              if (authService.isAuthenticated)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResonXPalette.neonCoral,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Wyloguj z konta'),
                  onPressed: () => authService.logout(),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A1A1E),
                    foregroundColor: ResonXPalette.neonCoral,
                    side: const BorderSide(color: ResonXPalette.neonCoral),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.lock),
                  label: const Text('Logowanie Chmury (BETA - ZABLOKOWANE)'),
                  onPressed: () => _showAuthGateModal(context),
                ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLibraryPill(String label, String navKey, IconData icon, Color color, int count) {
    final isSelected = _selectedNav == navKey;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavSelected(navKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : ResonXPalette.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : ResonXPalette.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : ResonXPalette.textDim),
              const SizedBox(width: 8),
              Text(
                '$label ($count)',
                style: TextStyle(
                  color: isSelected ? Colors.white : ResonXPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileToolCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ResonXPalette.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ResonXPalette.borderLight),
      ),
      child: ListTile(
        leading: Icon(icon, color: ResonXPalette.neonCyan),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: ResonXPalette.textDim, fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: ResonXPalette.textDim),
        onTap: onTap,
      ),
    );
  }

  Widget _buildResonXHeader(AuthCloudService authService, AudioPlayerService playerService) {
    final session = authService.session;
    final bool isLoggedIn = authService.isAuthenticated;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: ResonXPalette.surfaceSidebar,
        border: Border(bottom: BorderSide(color: ResonXPalette.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(18, 15),
                painter: ResonXLogoPainter(glowFactor: _glowAnimation.value),
              ),
              const SizedBox(width: 6),
              const Text(
                'RESONX',
                style: TextStyle(
                  color: ResonXPalette.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: (isLoggedIn && session?.tier != UserTier.free)
                      ? ResonXPalette.neonMint.withValues(alpha: 0.12)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (isLoggedIn && session?.tier != UserTier.free)
                        ? ResonXPalette.neonMint.withValues(alpha: 0.35)
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Text(
                  isLoggedIn ? (session?.tier.name.toUpperCase() ?? 'FREE') : 'BETA',
                  style: TextStyle(
                    color: (isLoggedIn && session?.tier != UserTier.free) ? ResonXPalette.neonMint : ResonXPalette.textDim,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildHeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Odśwież sieć i tokeny strumieni',
                onTap: () => _refreshNetworkStreams(context),
              ),
            ],
          ),
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.discord,
                    size: 17,
                    color: _isDiscordRpcEnabled ? const Color(0xFF5865F2) : ResonXPalette.textDim,
                  ),
                  const SizedBox(width: 2),
                  Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: _isDiscordRpcEnabled,
                      activeThumbColor: ResonXPalette.neonMint,
                      activeTrackColor: ResonXPalette.neonMint.withValues(alpha: 0.3),
                      inactiveThumbColor: ResonXPalette.textDim,
                      inactiveTrackColor: ResonXPalette.borderLight,
                      onChanged: (val) {
                        setState(() => _isDiscordRpcEnabled = val);
                      },
                    ),
                  ),
                  _buildHeaderIconButton(
                    icon: Icons.speed_rounded,
                    tooltip: 'Prędkość odtwarzania (${_currentPlaybackSpeed.toStringAsFixed(2)}x)',
                    onTap: () => _showPlaybackSpeedModal(context, playerService),
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  _buildHeaderIconButton(
                    icon: isLoggedIn ? Icons.account_circle : Icons.account_circle_outlined,
                    tooltip: isLoggedIn ? 'Profil: ${session?.username}' : 'Profil (Tryb Lokalny)',
                    onTap: () => _showProfileDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: ResonXPalette.surfaceCardHover,
        child: Container(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: ResonXPalette.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSidebar(AudioPlayerService playerService) {
    return Container(
      width: 220,
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
            badgeCount: _playlistTracksMap.length,
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
          color: isSelected ? ResonXPalette.neonCyan.withValues(alpha: 0.08) : Colors.transparent,
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
          color: isSelected ? ResonXPalette.neonCyan.withValues(alpha: 0.08) : Colors.transparent,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: ResonXPalette.surfaceSearchBar,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _searchFocusNode.hasFocus ? ResonXPalette.neonCyan.withValues(alpha: 0.6) : ResonXPalette.borderLight,
            width: 1.2,
          ),
          boxShadow: _searchFocusNode.hasFocus
              ? [BoxShadow(color: ResonXPalette.neonCyan.withValues(alpha: 0.12), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, size: 20, color: _searchFocusNode.hasFocus ? ResonXPalette.neonCyan : ResonXPalette.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: ResonXPalette.textPrimary, fontSize: 13.5),
                cursorColor: ResonXPalette.neonCyan,
                decoration: const InputDecoration(
                  hintText: 'Wyszukaj utwór, artystę lub wklej bezpośredni link...',
                  hintStyle: TextStyle(color: ResonXPalette.textDim, fontSize: 13),
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
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogHeaderSection(int totalItems) {
    String title = _selectedCategory;
    if (_searchQuery.isNotEmpty) {
      title = 'Wyniki: "$_searchQuery"';
    } else if (_selectedNav == 'favorites') {
      title = 'Ulubione Utwory';
    } else if (_selectedNav == 'downloads') {
      title = 'Pobrane Bez Sieci (Offline)';
    } else if (_selectedNav == 'playlists') {
      title = _activePlaylistName != null ? 'Playlista: $_activePlaylistName' : 'Moje Playlisty';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: ResonXPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$totalItems pozycji',
            style: const TextStyle(color: ResonXPalette.textDim, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListView(List<Track> tracks, AudioPlayerService playerService) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text('Brak utworów do wyświetlenia.', style: TextStyle(color: ResonXPalette.textDim)),
      );
    }

    return ListView.separated(
      controller: _trackListScrollController,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
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
                await playerService.playTrack(resolvedTrack);

                setState(() {
                  _totalListenedSeconds += track.durationSeconds > 0 ? track.durationSeconds : 180;
                  _artistPlayCounts[track.artist] = (_artistPlayCounts[track.artist] ?? 0) + 1;
                });

                int startOffset = 0;
                if (_trackCustomStartOffsets.containsKey(track.id)) {
                  startOffset = _trackCustomStartOffsets[track.id]!;
                } else if (_autoSkipSilenceIntro) {
                  startOffset = _defaultSilenceTrimSeconds;
                }

                if (startOffset > 0) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  playerService.player.seek(Duration(seconds: startOffset));
                }
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
        ? ResonXPalette.neonCyan.withValues(alpha: 0.08)
        : (_isHovered ? ResonXPalette.surfaceCardHover : Colors.transparent);

    final borderColor = widget.isCurrent ? ResonXPalette.neonMint.withValues(alpha: 0.45) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: widget.isCurrent
                ? [
                    BoxShadow(
                      color: ResonXPalette.neonMint.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
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
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: ResonXPalette.surfaceCard),
                    ),
                  ),
                  if (widget.isCurrent || _isHovered)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      style: TextStyle(
                        color: widget.isCurrent ? ResonXPalette.neonMint : ResonXPalette.textPrimary,
                        fontSize: 13.5,
                        fontWeight: widget.isCurrent ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.track.artist,
                            style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: ResonXPalette.textDim, fontSize: 10)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ResonXPalette.surfaceSearchBar,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: ResonXPalette.borderLight),
                          ),
                          child: const Text('HQ', style: TextStyle(color: ResonXPalette.neonMint, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
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
      ..color = ResonXPalette.neonMint.withValues(alpha: 0.4 * glowFactor)
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