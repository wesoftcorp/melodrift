import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../core/services/audio_handler.dart';

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<Song> queue;
  final double volume;
  final double speed;
  final bool isShuffle;
  final bool isRepeat;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.volume = 1.0,
    this.speed = 1.0,
    this.isShuffle = false,
    this.isRepeat = false,
  });

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<Song>? queue,
    double? volume,
    double? speed,
    bool? isShuffle,
    bool? isRepeat,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
    );
  }
}

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final repository = ref.watch(musicRepositoryProvider);
  return PlayerNotifier(handler, repository);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final MelodriftAudioHandler _handler;
  final MusicRepository _repository;
  
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<List<MediaItem>>? _queueSubscription;

  PlayerNotifier(this._handler, this._repository) : super(const PlayerState()) {
    _subscribe();
  }

  void _subscribe() {
    // 1. Current Song
    _mediaItemSubscription = _handler.mediaItem.listen((item) {
      if (item != null) {
        state = state.copyWith(
          currentSong: _mapMediaItemToSong(item),
          duration: item.duration ?? Duration.zero,
        );
        unawaited(_resolveNextInQueue()); // Trigger pre-resolution
      }
    });

    // 2. Playback State
    _playbackStateSubscription = _handler.playbackState.listen((pState) {
      state = state.copyWith(
        isPlaying: pState.playing,
        isLoading: pState.processingState == AudioProcessingState.buffering ||
                   pState.processingState == AudioProcessingState.loading,
        position: pState.updatePosition,
        bufferedPosition: pState.bufferedPosition,
        speed: pState.speed,
        isShuffle: pState.shuffleMode != AudioServiceShuffleMode.none,
        isRepeat: pState.repeatMode != AudioServiceRepeatMode.none,
      );
    });

    // 3. Queue
    _queueSubscription = _handler.queue.listen((mItems) {
      state = state.copyWith(
        queue: mItems.map(_mapMediaItemToSong).toList(),
      );
    });
  }

  // --- Mappings ---

  MediaItem _mapSongToMediaItem(Song song, {String? streamUrl}) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.artworkUrl.isNotEmpty ? Uri.parse(song.artworkUrl) : null,
      extras: {
        'streamUrl': streamUrl ?? song.streamUrl,
        'videoId': song.videoId,
      },
    );
  }

  Song _mapMediaItemToSong(MediaItem item) {
    return Song(
      id: item.id,
      title: item.title,
      artist: item.artist ?? '',
      album: item.album ?? '',
      duration: item.duration ?? Duration.zero,
      artworkUrl: item.artUri?.toString() ?? '',
      streamUrl: item.extras?['streamUrl'] as String?,
      videoId: item.extras?['videoId'] as String? ?? item.id,
    );
  }

  // --- Helper to resolve stream ---

  Future<String> _resolveStream(String videoId) async {
    try {
      return await _repository.getStreamUrl(videoId, quality: 'High');
    } catch (_) {
      return '';
    }
  }

  // Pre-resolve next song in queue for gapless playback
  Future<void> _resolveNextInQueue() async {
    final currentSong = state.currentSong;
    if (currentSong == null || state.queue.isEmpty) return;

    final currentIndex = state.queue.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1 || currentIndex + 1 >= state.queue.length) return;

    final nextSong = state.queue[currentIndex + 1];
    if (nextSong.streamUrl != null && nextSong.streamUrl!.isNotEmpty) return;

    // Resolve URL asynchronously in background
    final resolvedUrl = await _resolveStream(nextSong.videoId);
    if (resolvedUrl.isNotEmpty) {
      final updatedQueue = List<MediaItem>.from(_handler.queue.value);
      final nextIndex = currentIndex + 1;
      if (nextIndex < updatedQueue.length && updatedQueue[nextIndex].id == nextSong.id) {
        final extras = Map<String, dynamic>.from(updatedQueue[nextIndex].extras ?? {});
        extras['streamUrl'] = resolvedUrl;
        updatedQueue[nextIndex] = updatedQueue[nextIndex].copyWith(extras: extras);
        await _handler.updateQueue(updatedQueue);
      }
    }
  }

  // --- Playback Commands ---

  Future<void> playSong(Song song) async {
    state = state.copyWith(isLoading: true);
    final streamUrl = song.streamUrl ?? await _resolveStream(song.videoId);
    
    final mediaItem = _mapSongToMediaItem(song, streamUrl: streamUrl);
    await _handler.updateQueue([mediaItem]);
    await _handler.play();
  }

  Future<void> playQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    state = state.copyWith(isLoading: true);

    // Build initial media items (resolve first song right away, rest are background-resolved)
    final resolvedFirstUrl = songs[initialIndex].streamUrl ?? await _resolveStream(songs[initialIndex].videoId);
    
    final mItems = <MediaItem>[];
    for (int i = 0; i < songs.length; i++) {
      if (i == initialIndex) {
        mItems.add(_mapSongToMediaItem(songs[i], streamUrl: resolvedFirstUrl));
      } else {
        mItems.add(_mapSongToMediaItem(songs[i]));
      }
    }

    await _handler.updateQueue(mItems);
    await _handler.skipToQueueItem(initialIndex);
    await _handler.play();
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> setVolume(double volume) async {
    await _handler.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  Future<void> setSpeed(double speed) async {
    await _handler.setPlaybackSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> toggleShuffle() async {
    final mode = state.isShuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all;
    await _handler.setShuffleMode(mode);
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  Future<void> toggleRepeat() async {
    // Cycles through Repeat Modes: Off -> All -> Off
    AudioServiceRepeatMode serviceMode;
    if (!state.isRepeat) {
      serviceMode = AudioServiceRepeatMode.all;
    } else {
      serviceMode = AudioServiceRepeatMode.none;
    }
    await _handler.setRepeatMode(serviceMode);
    state = state.copyWith(isRepeat: serviceMode != AudioServiceRepeatMode.none);
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _queueSubscription?.cancel();
    super.dispose();
  }
}
