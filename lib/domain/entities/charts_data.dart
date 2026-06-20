import 'song.dart';
import 'artist.dart';
import 'album.dart';

class ChartsData {
  final List<Song> topSongs;
  final List<Artist> topArtists;
  final List<Album> topAlbums;

  const ChartsData({
    required this.topSongs,
    required this.topArtists,
    required this.topAlbums,
  });
}
