import 'song.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String artworkUrl;
  final int trackCount;
  final List<Song> songs;
  final bool isYouTube;
  final bool isLocal;

  const Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.artworkUrl,
    required this.trackCount,
    required this.songs,
    required this.isYouTube,
    required this.isLocal,
  });
}
