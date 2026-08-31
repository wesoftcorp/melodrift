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
  /// Top 50 trending songs for the Melodrift Trending Music cascade.
  final List<Song> trendingSongs;

  // Curated Multi-Service Sections
  final List<Album> featuredPlaylistsForYou;
  final List<Song> indianMusic;
  final List<Song> forgottenFavorites;
  final List<Album> albumsForYou;
  final List<Song> soundCloudLounge;
  final List<Song> spotifyTopHits;

  // New Rich Home Screen Segments
  final List<Song> top100India;
  final List<Song> top100International;
  final List<Song> internationalHits;
  final List<Song> punjabiHits;
  final List<Song> romanticMelodies;
  final List<Song> partyDanceMix;

  const HomeData({
    required this.quickPicks,
    required this.newReleases,
    required this.charts,
    required this.moods,
    this.listenAgain = const [],
    this.recommendedArtists = const [],
    this.featuredPlaylist,
    this.trendingSongs = const [],
    this.featuredPlaylistsForYou = const [],
    this.indianMusic = const [],
    this.forgottenFavorites = const [],
    this.albumsForYou = const [],
    this.soundCloudLounge = const [],
    this.spotifyTopHits = const [],
    this.top100India = const [],
    this.top100International = const [],
    this.internationalHits = const [],
    this.punjabiHits = const [],
    this.romanticMelodies = const [],
    this.partyDanceMix = const [],
  });

}
