import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/local_music_source.dart';
import '../models/local_models.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final localSource = ref.watch(localMusicSourceProvider);
  return HistoryRepositoryImpl(localSource);
});

final listeningHistoryProvider = FutureProvider<List<Song>>((ref) async {
  final historyRepo = ref.watch(historyRepositoryProvider);
  return historyRepo.getListeningHistory();
});

class HistoryRepositoryImpl implements HistoryRepository {
  final LocalMusicSource _localSource;

  HistoryRepositoryImpl(this._localSource);

  @override
  Future<List<Song>> getListeningHistory() async {
    final list = await _localSource.getListeningHistory();
    return list.map((record) {
      String source = 'YouTube Music';
      if (record.songId.startsWith('jiosaavn_')) {
        source = 'JioSaavn';
      } else if (record.songId.startsWith('soundcloud_')) {
        source = 'SoundCloud';
      } else if (record.songId.startsWith('spotify_')) {
        source = 'Spotify';
      }
      return Song(
        id: record.songId,
        title: record.title,
        artist: record.artist,
        album: 'Single',
        duration: Duration.zero,
        artworkUrl: record.artworkUrl,
        videoId: record.songId,
        source: source,
      );
    }).toList();
  }

  @override
  Future<void> addSongToHistory(Song song) async {
    final record = ListeningHistoryRecord()
      ..songId = song.id
      ..title = song.title
      ..artist = song.artist
      ..artworkUrl = song.artworkUrl
      ..playedAt = DateTime.now();
    await _localSource.saveListeningHistoryRecord(record);
  }

  @override
  Future<void> clearListeningHistory() async {
    await _localSource.clearListeningHistory();
  }

  @override
  Future<List<String>> getSearchHistory() async {
    final list = await _localSource.getSearchHistory();
    return list.map((record) => record.query).toList();
  }

  @override
  Future<void> addSearchQuery(String query) async {
    final record = SearchHistoryRecord()
      ..query = query
      ..searchedAt = DateTime.now();
    await _localSource.saveSearchHistoryRecord(record);
  }

  @override
  Future<void> deleteSearchQuery(String query) async {
    await _localSource.deleteSearchHistoryRecord(query);
  }

  @override
  Future<void> clearSearchHistory() async {
    await _localSource.clearSearchHistory();
  }
}
