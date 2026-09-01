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

  /// Dedicated Hindi Hits section — always shows Hindi/Bollywood songs regardless of language filter.
  final List<Song> hindiHits;

  /// Sufi & Ghazals — soulful qawwali/sufi/ghazal songs.
  final List<Song> sufiGhazals;

  /// Devotional & Bhakti — bhajans, aartis, devotional songs.
  final List<Song> devotionalBhakti;

  /// 90s Retro Throwback — evergreen classics from the golden Bollywood era.
  final List<Song> retro90s;

  /// Bhangra & Dhol — high energy Punjabi dhol and bhangra party tracks.
  final List<Song> bhangraDhol;

  /// Indie Hindi — independent Hindi tracks, typically from SoundCloud.
  final List<Song> indieHindi;

  /// Spotify India Top 50 — songs from Spotify's India Top 50 curated playlist.
  final List<Song> spotifyIndiaTop50;

  /// New Music Friday India — songs from Spotify's New Music Friday India playlist.
  final List<Song> newMusicFridayIndia;

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
    this.hindiHits = const [],
    this.sufiGhazals = const [],
    this.devotionalBhakti = const [],
    this.retro90s = const [],
    this.bhangraDhol = const [],
    this.indieHindi = const [],
    this.spotifyIndiaTop50 = const [],
    this.newMusicFridayIndia = const [],
  });

}
