import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistExporterService {
  static final PlaylistExporterService instance = PlaylistExporterService._();
  PlaylistExporterService._();

  Future<String> exportToJson(Playlist playlist) async {
    final Map<String, dynamic> data = playlist.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/resonx_${playlist.id}_export.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  Future<String> exportToM3u(Playlist playlist) async {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:${playlist.title}');

    for (final track in playlist.tracks) {
      buffer.writeln('#EXTINF:${track.durationSeconds},${track.artist} - ${track.title}');
      if (track.isOffline && track.localPath != null) {
        buffer.writeln(track.localPath);
      } else {
        buffer.writeln(track.audioUrl);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${playlist.title.replaceAll(RegExp(r'[^\w\s]+'), '_')}.m3u8');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Playlist importFromJson(String rawJson) {
    final Map<String, dynamic> data = jsonDecode(rawJson);
    return Playlist.fromJson(data);
  }

  Playlist importFromM3u(String rawM3u, String playlistName) {
    final lines = rawM3u.split('\n');
    final List<Track> tracks = [];

    String currentTitle = '';
    String currentArtist = '';
    int currentDuration = 180;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final content = line.substring(8);
        final commaIndex = content.indexOf(',');
        if (commaIndex != -1) {
          final durStr = content.substring(0, commaIndex);
          currentDuration = int.tryParse(durStr) ?? 180;
          final meta = content.substring(commaIndex + 1);
          final splitMeta = meta.split(' - ');
          if (splitMeta.length >= 2) {
            currentArtist = splitMeta[0].trim();
            currentTitle = splitMeta.sublist(1).join(' - ').trim();
          } else {
            currentArtist = 'Nieznany wykonawca';
            currentTitle = meta.trim();
          }
        }
      } else if (!line.startsWith('#')) {
        final track = Track(
          id: 'imported_${DateTime.now().microsecondsSinceEpoch}_${tracks.length}',
          title: currentTitle.isNotEmpty ? currentTitle : 'Ścieżka ${tracks.length + 1}',
          artist: currentArtist.isNotEmpty ? currentArtist : 'Wykonawca',
          album: playlistName,
          coverUrl: 'https://picsum.photos/400/400',
          audioUrl: line,
          durationSeconds: currentDuration,
          isOffline: !line.startsWith('http'),
          localPath: !line.startsWith('http') ? line : null,
        );
        tracks.add(track);
        currentTitle = '';
        currentArtist = '';
        currentDuration = 180;
      }
    }

    return Playlist(
      id: 'pl_m3u_${DateTime.now().millisecondsSinceEpoch}',
      title: playlistName,
      tracks: tracks,
    );
  }
}