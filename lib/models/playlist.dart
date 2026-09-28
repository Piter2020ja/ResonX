import 'track.dart';

class Playlist {
  final String id;
  String title;
  String description;
  final int createdTimestamp;
  final List<Track> tracks;

  Playlist({
    required this.id,
    required this.title,
    this.description = '',
    int? createdTimestamp,
    List<Track>? tracks,
  })  : createdTimestamp = createdTimestamp ?? DateTime.now().millisecondsSinceEpoch,
        tracks = tracks ?? [];

  int get trackCount => tracks.length;

  int get totalDurationSeconds =>
      tracks.fold(0, (sum, track) => sum + track.durationSeconds);

  bool containsTrack(String trackId) {
    return tracks.any((t) => t.id == trackId);
  }

  bool hasFuzzyDuplicate(String title, String artist) {
    final cleanTitle = title.trim().toLowerCase();
    final cleanArtist = artist.trim().toLowerCase();
    return tracks.any((t) {
      final tTitle = t.title.trim().toLowerCase();
      final tArtist = t.artist.trim().toLowerCase();
      return (tTitle == cleanTitle && tArtist == cleanArtist) ||
          (tTitle.contains(cleanTitle) && tArtist == cleanArtist);
    });
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'createdTimestamp': createdTimestamp,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        createdTimestamp: json['createdTimestamp'],
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => Track.fromJson(t))
                .toList() ??
            [],
      );
}