class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artworkUrl;
  final String? streamUrl;
  final String videoId;
  final String source;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artworkUrl,
    required this.videoId,
    this.streamUrl,
    this.source = 'JioSaavn',
  });
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          videoId == other.videoId &&
          title == other.title &&
          artist == other.artist &&
          streamUrl == other.streamUrl;

  @override
  int get hashCode => Object.hash(id, videoId, title, artist, streamUrl);
}

