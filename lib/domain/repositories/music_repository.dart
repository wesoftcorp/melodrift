import '../entities/song.dart';
import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/playlist.dart';
import '../entities/home_data.dart';
import '../entities/charts_data.dart';

abstract class MusicRepository {
  /// Search for songs by query
  Future<List<Song>> searchSongs(String query);

  /// Search for albums by query
  Future<List<Album>> searchAlbums(String query);

  /// Search for artists by query
  Future<List<Artist>> searchArtists(String query);

  /// Fetch customized home feed data
  Future<HomeData> getHomeFeed({String? language});

  /// Get details of an album, including its tracklist
  Future<Album> getAlbumDetails(String albumId, {String? fallbackTitle});

  /// Get details of an artist
  Future<Artist> getArtistDetails(String artistId);

  /// Get details of a playlist, including its tracklist
  Future<Playlist> getPlaylistDetails(String playlistId);

  /// Get audio stream URL for playback
  Future<String> getStreamUrl(String videoId, {String quality = 'High'});

  /// Get video stream URL for video player mode
  Future<String> getVideoStreamUrl(String videoId);

  /// Get related/recommended songs for a given track
  Future<List<Song>> getRelatedSongs(String videoId);

  /// Get charts (top songs/albums)
  Future<ChartsData> getCharts({String? country});

  /// Get search suggestions/autocomplete
  Future<List<String>> getSearchSuggestions(String query);

  /// Get at least 100 curated songs for a mood or genre category
  Future<List<Song>> getMoodCategorySongs(String moodId, String moodTitle, {int limit = 100});
}
