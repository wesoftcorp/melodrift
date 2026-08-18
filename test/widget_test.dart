import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:melodrift/app.dart';
import 'package:melodrift/flavors.dart';
import 'package:melodrift/core/theme/theme_provider.dart';
import 'package:melodrift/core/services/audio_handler.dart';
import 'package:melodrift/domain/repositories/music_repository.dart';
import 'package:melodrift/data/repositories/music_repository_impl.dart';
import 'package:melodrift/data/datasources/local_music_source.dart';
import 'package:melodrift/domain/entities/song.dart';
import 'package:melodrift/domain/entities/album.dart';
import 'package:melodrift/domain/entities/artist.dart';
import 'package:melodrift/domain/entities/playlist.dart';
import 'package:melodrift/domain/entities/home_data.dart';
import 'package:melodrift/domain/entities/charts_data.dart';
import 'package:melodrift/data/models/local_models.dart';

class MockMelodriftAudioHandler extends BaseAudioHandler implements MelodriftAudioHandler {
  final BehaviorSubject<PlaybackState> _playbackState = BehaviorSubject.seeded(
    PlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
    ),
  );

  final BehaviorSubject<MediaItem?> _mediaItem = BehaviorSubject.seeded(null);

  final BehaviorSubject<List<MediaItem>> _queue = BehaviorSubject.seeded([]);

  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackState;

  @override
  Future<void> setEqualizerPreset(String preset) async {}


  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItem;

  @override
  BehaviorSubject<List<MediaItem>> get queue => _queue;

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {}

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {}

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {}

  @override
  Future<void> updateQueue(List<MediaItem> queue, {int initialIndex = 0}) async {
    this.queue.add(queue);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {}

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {}

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Stream<Duration?> get durationStream => Stream.value(Duration.zero);

  @override
  Stream<Duration> get bufferedPositionStream => Stream.value(Duration.zero);

  @override
  List<int> get effectiveIndices => [];

  @override
  Future<void> moveQueueItem(int fromIndex, int toIndex) async {}
}

class MockMusicRepository implements MusicRepository {
  @override
  Future<List<Song>> searchSongs(String query) async => [];

  @override
  Future<List<Album>> searchAlbums(String query) async => [];

  @override
  Future<List<Artist>> searchArtists(String query) async => [];

  @override
  Future<HomeData> getHomeFeed({String? language}) async => const HomeData(
        quickPicks: [],
        newReleases: [],
        charts: [],
        moods: [],
      );

  @override
  Future<Album> getAlbumDetails(String albumId) async => const Album(
        id: '',
        title: '',
        artist: '',
        artworkUrl: '',
        tracks: [],
        songCount: 0,
      );

  @override
  Future<Artist> getArtistDetails(String artistId) async => const Artist(
        id: '',
        name: '',
        artworkUrl: '',
      );

  @override
  Future<Playlist> getPlaylistDetails(String playlistId) async => const Playlist(
        id: '',
        title: '',
        description: '',
        artworkUrl: '',
        trackCount: 0,
        songs: [],
        isYouTube: false,
        isLocal: false,
      );

  @override
  Future<String> getStreamUrl(String videoId, {String quality = 'High'}) async => '';

  @override
  Future<String> getVideoStreamUrl(String videoId) async => '';

  @override
  Future<List<Song>> getRelatedSongs(String videoId) async => [];

  @override
  Future<ChartsData> getCharts({String? country}) async => const ChartsData(
        topSongs: [],
        topArtists: [],
        topAlbums: [],
      );

  @override
  Future<List<String>> getSearchSuggestions(String query) async => [];
}

class MockLocalMusicSource implements LocalMusicSource {
  @override
  Future<void> saveSong(LocalSong song) async {}

  @override
  Future<LocalSong?> getSong(String songId) async => null;

  @override
  Future<List<LocalSong>> getDownloadedSongs() async => [];

  @override
  Future<void> deleteSong(String songId) async {}

  @override
  Future<void> savePlaylist(LocalPlaylist playlist) async {}

  @override
  Future<LocalPlaylist?> getPlaylist(String playlistId) async => null;

  @override
  Future<List<LocalPlaylist>> getAllPlaylists() async => [];

  @override
  Stream<List<LocalPlaylist>> watchAllPlaylists() => Stream.value([]);

  @override
  Future<void> deletePlaylist(String playlistId) async {}

  @override
  Future<void> addSongToPlaylist(String playlistId, LocalSong song) async {}

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {}

  @override
  Future<void> saveDownloadRecord(DownloadRecord record) async {}

  @override
  Future<DownloadRecord?> getDownloadRecord(String songId) async => null;

  @override
  Future<List<DownloadRecord>> getAllDownloadRecords() async => [];

  @override
  Future<void> deleteDownloadRecord(String songId) async {}

  @override
  Stream<List<DownloadRecord>> watchDownloadRecords() => Stream.value([]);

  @override
  Future<void> saveListeningHistoryRecord(ListeningHistoryRecord record) async {}

  @override
  Future<List<ListeningHistoryRecord>> getListeningHistory() async => [];

  @override
  Future<void> clearListeningHistory() async {}

  @override
  Future<void> saveSearchHistoryRecord(SearchHistoryRecord record) async {}

  @override
  Future<List<SearchHistoryRecord>> getSearchHistory() async => [];

  @override
  Future<void> deleteSearchHistoryRecord(String query) async {}

  @override
  Future<void> clearSearchHistory() async {}
}

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    F.appFlavor = Flavor.devfoss;
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioHandlerProvider.overrideWithValue(MockMelodriftAudioHandler()),
          musicRepositoryProvider.overrideWithValue(MockMusicRepository()),
          localMusicSourceProvider.overrideWithValue(MockLocalMusicSource()),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app is initialized and has a root App widget
    expect(find.byType(App), findsOneWidget);
  });
}
