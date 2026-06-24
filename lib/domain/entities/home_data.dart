import 'song.dart';
import 'album.dart';
import 'artist.dart';
import 'mood_category.dart';

class HomeData {
  final List<Song> quickPicks;
  final List<Album> newReleases;
  final List<Song> charts;
  final List<MoodCategory> moods;
  /// "Listen Again" – a second set of popular songs surfaced as a compact row.
  final List<Song> listenAgain;
  /// Artist spotlight chips shown in a horizontal row.
  final List<Artist> recommendedArtists;
  /// Optional hero playlist / featured album shown at the top.
  final Album? featuredPlaylist;

  // New Rich Sections
  final List<Album> featuredPlaylistsForYou;
  final List<Song> indianMusic;
  final List<Song> forgottenFavorites;
  final List<Album> albumsForYou;

  const HomeData({
    required this.quickPicks,
    required this.newReleases,
    required this.charts,
    required this.moods,
    this.listenAgain = const [],
    this.recommendedArtists = const [],
    this.featuredPlaylist,
    this.featuredPlaylistsForYou = const [],
    this.indianMusic = const [],
    this.forgottenFavorites = const [],
    this.albumsForYou = const [],
  });
}
