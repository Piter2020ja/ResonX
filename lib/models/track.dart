class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String coverUrl;
  final String audioUrl;
  final String? localPath;
  final bool isFavorite;
  final bool isOffline;
  final String fileFormat;
  final int bitrate;
  final int sampleRate;
  final int addedTimestamp;
  final int playCount;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.coverUrl,
    required this.audioUrl,
    this.localPath,
    this.isFavorite = false,
    this.isOffline = false,
    this.fileFormat = 'MP3',
    this.bitrate = 320,
    this.sampleRate = 44100,
    this.addedTimestamp = 0,
    this.playCount = 0,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? coverUrl,
    String? audioUrl,
    String? localPath,
    bool? isFavorite,
    bool? isOffline,
    String? fileFormat,
    int? bitrate,
    int? sampleRate,
    int? addedTimestamp,
    int? playCount,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      localPath: localPath ?? this.localPath,
      isFavorite: isFavorite ?? this.isFavorite,
      isOffline: isOffline ?? this.isOffline,
      fileFormat: fileFormat ?? this.fileFormat,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      addedTimestamp: addedTimestamp ?? this.addedTimestamp,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': durationSeconds,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'localPath': localPath,
      'isFavorite': isFavorite,
      'isOffline': isOffline,
      'fileFormat': fileFormat,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'addedTimestamp': addedTimestamp,
      'playCount': playCount,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Nieznany tytuł',
      artist: map['artist'] as String? ?? 'Nieznany wykonawca',
      album: map['album'] as String? ?? 'ResonX Master',
      durationSeconds: map['durationSeconds'] as int? ?? 180,
      coverUrl: map['coverUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
      localPath: map['localPath'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isOffline: map['isOffline'] as bool? ?? false,
      fileFormat: map['fileFormat'] as String? ?? 'MP3',
      bitrate: map['bitrate'] as int? ?? 320,
      sampleRate: map['sampleRate'] as int? ?? 44100,
      addedTimestamp: map['addedTimestamp'] as int? ?? 0,
      playCount: map['playCount'] as int? ?? 0,
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) => Track.fromMap(json);
}