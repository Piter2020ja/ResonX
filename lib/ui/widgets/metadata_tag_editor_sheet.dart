import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/track.dart';
import '../../services/database_service.dart';

class MetadataTagEditorSheet extends StatefulWidget {
  final Track track;
  final VoidCallback onSaved;

  const MetadataTagEditorSheet({
    super.key,
    required this.track,
    required this.onSaved,
  });

  @override
  State<MetadataTagEditorSheet> createState() => _MetadataTagEditorSheetState();
}

class _MetadataTagEditorSheetState extends State<MetadataTagEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _coverUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album);
    _coverUrlController = TextEditingController(text: widget.track.coverUrl);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();
    final cover = _coverUrlController.text.trim();

    if (title.isEmpty || artist.isEmpty) return;

    setState(() => _isSaving = true);

    final updatedTrack = Track(
      id: widget.track.id,
      title: title,
      artist: artist,
      album: album.isNotEmpty ? album : widget.track.album,
      coverUrl: cover.isNotEmpty ? cover : widget.track.coverUrl,
      audioUrl: widget.track.audioUrl,
      durationSeconds: widget.track.durationSeconds,
      bitrate: widget.track.bitrate,
      sampleRate: widget.track.sampleRate,
      fileFormat: widget.track.fileFormat,
      isFavorite: widget.track.isFavorite,
      isOffline: widget.track.isOffline,
      localPath: widget.track.localPath,
      addedTimestamp: widget.track.addedTimestamp,
      playCount: widget.track.playCount,
    );

    await DatabaseService.instance.saveTrack(updatedTrack);
    widget.onSaved();

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: ResonXColors.surfaceBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ResonXColors.cardBorder, width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: ResonXColors.cyberJade, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Edytor Tagów Metadanych',
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
            _buildField('Tytuł Utworu', _titleController, Icons.music_note),
            const SizedBox(height: 12),
            _buildField('Wykonawca / Artysta', _artistController, Icons.person),
            const SizedBox(height: 12),
            _buildField('Album', _albumController, Icons.album),
            const SizedBox(height: 12),
            _buildField('URL Okładki', _coverUrlController, Icons.image),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ResonXColors.cyberJade,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Zapisz Metadane w Bazie SQLite', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: ResonXColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: ResonXColors.textSecondary),
        prefixIcon: Icon(icon, color: ResonXColors.cyberJade, size: 20),
        filled: true,
        fillColor: ResonXColors.deepGraphite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ResonXColors.cardBorder),
        ),
      ),
    );
  }
}