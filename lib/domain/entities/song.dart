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
}

