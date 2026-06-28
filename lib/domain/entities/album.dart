import 'song.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final int? year;
  final List<Song> tracks;
  final int songCount;
  final String source;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.tracks,
    required this.songCount,
    this.year,
    this.source = 'YouTube Music',
  });
}
