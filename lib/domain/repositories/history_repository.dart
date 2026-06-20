import '../entities/song.dart';

abstract class HistoryRepository {
  /// Fetch listening history
  Future<List<Song>> getListeningHistory();

  /// Add a song to the history log
  Future<void> addSongToHistory(Song song);

  /// Clear the complete listening history
  Future<void> clearListeningHistory();

  /// Fetch past search queries (newest first)
  Future<List<String>> getSearchHistory();

  /// Add a search query to history
  Future<void> addSearchQuery(String query);

  /// Delete a single search query
  Future<void> deleteSearchQuery(String query);

  /// Clear the complete search history
  Future<void> clearSearchHistory();
}
