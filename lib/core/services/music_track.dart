class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artworkUrl;
  final String? streamUrl;
  final String source; // 'jiosaavn', 'soundcloud', 'spotify'
  final Map<String, dynamic> extras;


  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artworkUrl,
    required this.source,
    this.streamUrl,
    this.extras = const {},
  });

  factory MusicTrack.fromMap(Map<String, dynamic> map) {
    return MusicTrack(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      duration: Duration(seconds: map['durationSeconds'] as int),
      artworkUrl: map['artworkUrl'] as String,
      source: map['source'] as String,
      streamUrl: map['streamUrl'] as String?,
      extras: Map<String, dynamic>.from(map['extras'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': duration.inSeconds,
      'artworkUrl': artworkUrl,
      'streamUrl': streamUrl,
      'source': source,
      'extras': extras,
    };
  }

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkUrl,
    String? streamUrl,
    String? source,
    Map<String, dynamic>? extras,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      source: source ?? this.source,
      extras: extras ?? this.extras,
    );
  }

  @override
  String toString() => 'MusicTrack(id: $id, title: $title, artist: $artist, source: $source)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicTrack &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source;

  @override
  int get hashCode => id.hashCode ^ source.hashCode;
}
