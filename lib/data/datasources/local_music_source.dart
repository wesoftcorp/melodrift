import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_models.dart';

final localMusicSourceProvider = Provider<LocalMusicSource>((ref) {
  final isar = ref.watch(isarProvider);
  return LocalMusicSource(isar);
});

final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('Isar is not initialized yet. Override isarProvider in ProviderScope.');
});

class LocalMusicSource {
  final Isar _isar;

  LocalMusicSource(this._isar);

  // --- Songs ---

  /// Save or update a local song
  Future<void> saveSong(LocalSong song) async {
    await _isar.writeTxn(() async {
      await _isar.localSongs.put(song);
    });
  }

  /// Get a song by its YouTube/local song ID
  Future<LocalSong?> getSong(String songId) async {
    return await _isar.localSongs.filter().songIdEqualTo(songId).findFirst();
  }

  /// Get all songs marked as downloaded
  Future<List<LocalSong>> getDownloadedSongs() async {
    return await _isar.localSongs.filter().isDownloadedEqualTo(true).findAll();
  }

  /// Delete a song from local database
  Future<void> deleteSong(String songId) async {
    await _isar.writeTxn(() async {
      final song = await getSong(songId);
      if (song != null) {
        await _isar.localSongs.delete(song.id);
      }
    });
  }

  // --- Playlists ---

  /// Save or update a playlist
  Future<void> savePlaylist(LocalPlaylist playlist) async {
    await _isar.writeTxn(() async {
      await _isar.localPlaylists.put(playlist);
    });
  }

  /// Get a playlist by ID
  Future<LocalPlaylist?> getPlaylist(String playlistId) async {
    final playlist = await _isar.localPlaylists.filter().playlistIdEqualTo(playlistId).findFirst();
    if (playlist != null) {
      await playlist.songs.load();
    }
    return playlist;
  }

  /// Get all playlists (local and YouTube synced)
  Future<List<LocalPlaylist>> getAllPlaylists() async {
    final list = await _isar.localPlaylists.where().findAll();
    for (final playlist in list) {
      await playlist.songs.load();
    }
    return list;
  }

  /// Watch all playlists
  Stream<List<LocalPlaylist>> watchAllPlaylists() {
    return _isar.localPlaylists.where().watch(fireImmediately: true);
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    await _isar.writeTxn(() async {
      final playlist = await getPlaylist(playlistId);
      if (playlist != null) {
        await _isar.localPlaylists.delete(playlist.id);
      }
    });
  }

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(String playlistId, LocalSong song) async {
    await _isar.writeTxn(() async {
      final playlist = await _isar.localPlaylists.filter().playlistIdEqualTo(playlistId).findFirst();
      if (playlist == null) return;

      final existingSong = await _isar.localSongs.filter().songIdEqualTo(song.songId).findFirst();
      final songToLink = existingSong ?? song;

      if (existingSong == null) {
        await _isar.localSongs.put(songToLink);
      }

      await playlist.songs.load();
      if (!playlist.songs.any((s) => s.songId == song.songId)) {
        playlist.songs.add(songToLink);
        await playlist.songs.save();

        playlist.trackCount = playlist.songs.length;
        await _isar.localPlaylists.put(playlist);
      }
    });
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _isar.writeTxn(() async {
      final playlist = await _isar.localPlaylists.filter().playlistIdEqualTo(playlistId).findFirst();
      final song = await _isar.localSongs.filter().songIdEqualTo(songId).findFirst();
      if (playlist == null || song == null) return;

      await playlist.songs.load();
      if (playlist.songs.any((s) => s.songId == songId)) {
        playlist.songs.remove(song);
        await playlist.songs.save();

        playlist.trackCount = playlist.songs.length;
        await _isar.localPlaylists.put(playlist);
      }
    });
  }

  // --- Downloads ---

  /// Save or update a download record
  Future<void> saveDownloadRecord(DownloadRecord record) async {
    await _isar.writeTxn(() async {
      await _isar.downloadRecords.put(record);
    });
  }

  /// Get download record by song ID
  Future<DownloadRecord?> getDownloadRecord(String songId) async {
    return await _isar.downloadRecords.filter().songIdEqualTo(songId).findFirst();
  }

  /// Get all download records
  Future<List<DownloadRecord>> getAllDownloadRecords() async {
    return await _isar.downloadRecords.where().findAll();
  }

  /// Delete a download record
  Future<void> deleteDownloadRecord(String songId) async {
    await _isar.writeTxn(() async {
      final record = await getDownloadRecord(songId);
      if (record != null) {
        await _isar.downloadRecords.delete(record.id);
      }
    });
  }

  /// Watch active download records
  Stream<List<DownloadRecord>> watchDownloadRecords() {
    return _isar.downloadRecords.where().watch(fireImmediately: true);
  }

  // --- Listening History ---

  /// Save a listening history record
  Future<void> saveListeningHistoryRecord(ListeningHistoryRecord record) async {
    await _isar.writeTxn(() async {
      await _isar.listeningHistoryRecords.put(record);
    });
  }

  /// Get listening history sorted by played time (newest first)
  Future<List<ListeningHistoryRecord>> getListeningHistory() async {
    return await _isar.listeningHistoryRecords
        .where()
        .sortByPlayedAtDesc()
        .findAll();
  }

  /// Clear all listening history
  Future<void> clearListeningHistory() async {
    await _isar.writeTxn(() async {
      await _isar.listeningHistoryRecords.clear();
    });
  }

  // --- Search History ---

  /// Save a search history record
  Future<void> saveSearchHistoryRecord(SearchHistoryRecord record) async {
    await _isar.writeTxn(() async {
      await _isar.searchHistoryRecords.put(record);
    });
  }

  /// Get all search queries sorted by search time (newest first)
  Future<List<SearchHistoryRecord>> getSearchHistory() async {
    return await _isar.searchHistoryRecords
        .where()
        .sortBySearchedAtDesc()
        .findAll();
  }

  /// Delete a specific search history item
  Future<void> deleteSearchHistoryRecord(String query) async {
    await _isar.writeTxn(() async {
      final record = await _isar.searchHistoryRecords
          .filter()
          .queryEqualTo(query)
          .findFirst();
      if (record != null) {
        await _isar.searchHistoryRecords.delete(record.id);
      }
    });
  }

  /// Clear all search history
  Future<void> clearSearchHistory() async {
    await _isar.writeTxn(() async {
      await _isar.searchHistoryRecords.clear();
    });
  }
}
