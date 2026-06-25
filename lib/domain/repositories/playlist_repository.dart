import '../entities/playlist.dart';
import '../entities/song.dart';

abstract class PlaylistRepository {
  /// Get all local and synced playlists
  Future<List<Playlist>> getPlaylists();

  /// Get a single playlist by ID
  Future<Playlist?> getPlaylist(String id);

  /// Create a new playlist
  Future<void> createPlaylist(Playlist playlist);

  /// Delete a playlist
  Future<void> deletePlaylist(String id);

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(String playlistId, Song song);

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId);

  /// Watch all local and synced playlists
  Stream<List<Playlist>> watchPlaylists();
}
