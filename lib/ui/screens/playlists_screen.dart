import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';

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

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _playlistSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _searchQuery = '';
  String? _selectedPlaylistId = 'fav';

  @override
  void initState() {
    super.initState();
    _playlistSearchController.addListener(() {
      setState(() {
        _searchQuery = _playlistSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _playlistSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<AudioPlayerService>();

    return Scaffold(
      backgroundColor: ResonXPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(context),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildPlaylistsGrid(playerService),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _buildPlaylistDetailsPane(playerService),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ResonXPalette.neonCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ResonXPalette.neonCyan.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.queue_music_rounded, color: ResonXPalette.neonCyan, size: 26),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zarządzanie Playlistami',
                  style: TextStyle(
                    color: ResonXPalette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Twoje osobiste kolekcje muzyczne w jakości Lossless',
                  style: TextStyle(color: ResonXPalette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ResonXPalette.neonCyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 4,
            shadowColor: ResonXPalette.neonCyan.withValues(alpha: 0.4),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Nowa Playlista', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showCreatePlaylistDialog(context),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: ResonXPalette.surfaceSearchBar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ResonXPalette.borderLight),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: ResonXPalette.textDim, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _playlistSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Szukaj w playlistach...',
                hintStyle: TextStyle(color: ResonXPalette.textDim, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_playlistSearchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: ResonXPalette.textDim, size: 18),
              onPressed: () => _playlistSearchController.clear(),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildPlaylistsGrid(AudioPlayerService playerService) {
    final playlists = [
      {'id': 'fav', 'name': 'Ulubione Utwory', 'count': '${playerService.favoriteTrackIds.length} poz.', 'icon': Icons.favorite, 'color': ResonXPalette.neonCoral},
      {'id': 'trap', 'name': 'Ulubione Trap 2026', 'count': '18 poz.', 'icon': Icons.flash_on, 'color': ResonXPalette.neonCyan},
      {'id': 'night', 'name': 'Nocny Drill Katowice', 'count': '24 poz.', 'icon': Icons.nightlife, 'color': ResonXPalette.neonPurple},
      {'id': 'bass', 'name': 'Samochodowe Bass', 'count': '12 poz.', 'icon': Icons.speaker, 'color': ResonXPalette.neonMint},
    ];

    final filtered = playlists.where((p) => p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ResonXPalette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ResonXPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Twoje Kolekcje',
            style: TextStyle(color: ResonXPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final currentItem = filtered[index]; // Naprawiony błąd const na poziomie elementu
                final isSelected = _selectedPlaylistId == currentItem['id'];
                final iconColor = currentItem['color'] as Color;

                return Material(
                  color: isSelected ? ResonXPalette.surfaceCardHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPlaylistId = currentItem['id'] as String?;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? ResonXPalette.neonCyan.withValues(alpha: 0.5) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(currentItem['icon'] as IconData, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentItem['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentItem['count'] as String,
                                  style: const TextStyle(color: ResonXPalette.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: ResonXPalette.textDim, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistDetailsPane(AudioPlayerService playerService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ResonXPalette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ResonXPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: ResonXPalette.neonMint, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Zawartość Kolekcji',
                style: TextStyle(color: ResonXPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ResonXPalette.surfaceSearchBar,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedPlaylistId == 'fav' ? '${playerService.favoriteTrackIds.length} utworów' : 'Aktywna playlista',
                  style: const TextStyle(color: ResonXPalette.neonCyan, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: ResonXPalette.borderLight, height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.album_rounded, color: ResonXPalette.textDim.withValues(alpha: 0.4), size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'Kolekcja jest gotowa do odtwarzania.\nKliknij dowolny utwór wyszukany w katalogu głównym,\naby zarządzać kolejką.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ResonXPalette.textDim, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: ResonXPalette.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ResonXPalette.neonCyan, width: 1.2),
            ),
            title: const Text('Utwórz nową playlistę', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nazwa playlisty (np. Ulica 2026)...',
                hintStyle: const TextStyle(color: ResonXPalette.textDim),
                filled: true,
                fillColor: ResonXPalette.surfaceSearchBar,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anuluj', style: TextStyle(color: ResonXPalette.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ResonXPalette.neonCyan, foregroundColor: Colors.black),
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Utworzono nową playlistę: "$name"')),
                    );
                  }
                },
                child: const Text('Utwórz', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}