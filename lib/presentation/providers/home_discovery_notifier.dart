import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../core/utils/matching_engine.dart';

class HomeDiscoveryState {
  final List<Song> songs;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final int currentSeedIndex;

  const HomeDiscoveryState({
    this.songs = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.currentSeedIndex = 0,
  });

  HomeDiscoveryState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    int? currentSeedIndex,
  }) {
    return HomeDiscoveryState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      currentSeedIndex: currentSeedIndex ?? this.currentSeedIndex,
    );
  }
}

final homeDiscoveryProvider =
    StateNotifierProvider<HomeDiscoveryNotifier, HomeDiscoveryState>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return HomeDiscoveryNotifier(repo);
});

class HomeDiscoveryNotifier extends StateNotifier<HomeDiscoveryState> {
  final MusicRepository _repository;
  final Set<String> _seenKeys = {};

  static const List<String> _discoverySeeds = [
    'global top songs',
    'trending reels hits',
    'fresh indie acoustic',
    'latest bollywood chartbusters',
    'viral pop songs',
    'punjabi top tracks',
    'chill lo-fi beats',
    'electronic dance party',
    'heartfelt romantic ballads',
    'billboard hot singles',
    'soulful acoustic pop',
    'desi hip hop hits',
    'top international hits',
    'feel good morning music',
    'late night vibes',
    'workout energy pump',
    'retro pop hits',
    'unplugged melodies',
  ];

  HomeDiscoveryNotifier(this._repository) : super(const HomeDiscoveryState()) {
    initDiscovery();
  }

  String _makeSongKey(Song s) {
    final cleanTitle = normalizeTitle(s.title);
    final cleanArtist = s.artist
        .split(',')
        .first
        .split('&')
        .first
        .split('•')
        .first
        .trim()
        .toLowerCase();
    return '$cleanTitle|$cleanArtist';
  }

  /// Register existing home songs so infinite scrolling never repeats them
  void registerExistingSongs(List<Song> existing) {
    for (final s in existing) {
      _seenKeys.add(s.id);
      _seenKeys.add(_makeSongKey(s));
    }
  }

  Future<void> initDiscovery([List<Song>? initialSongs]) async {
    if (initialSongs != null && initialSongs.isNotEmpty) {
      registerExistingSongs(initialSongs);
    }
    if (state.songs.isEmpty) {
      await loadMore();
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, hasError: false);

    try {
      final seed = _discoverySeeds[state.currentSeedIndex % _discoverySeeds.length];
      final newSongs = await _repository.searchSongs(seed);

      final List<Song> deduplicated = [];
      for (final song in newSongs) {
        final key = _makeSongKey(song);
        if (!_seenKeys.contains(key) && !_seenKeys.contains(song.id)) {
          _seenKeys.add(key);
          _seenKeys.add(song.id);
          deduplicated.add(song);
        }
      }

      state = state.copyWith(
        songs: [...state.songs, ...deduplicated],
        isLoading: false,
        currentSeedIndex: state.currentSeedIndex + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    _seenKeys.clear();
    state = const HomeDiscoveryState();
    await loadMore();
  }
}
