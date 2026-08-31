import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/datasources/local_music_source.dart';
import '../../data/models/local_models.dart';
import '../../core/services/audio_handler.dart';
import '../../core/utils/logger.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/unified_stream_resolver.dart';
import '../../core/services/taste_profiler_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/analytics_service.dart';
import '../screens/settings_screen.dart' show allowExplicitContentProvider, autoplayEnabledProvider;
import '../../app.dart' show scaffoldMessengerKey;

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<Song> queue;
  final List<Song> playbackQueue;
  final double volume;
  final double speed;
  final bool isShuffle;
  final AudioServiceRepeatMode repeatMode;
  final Duration? sleepTimeRemaining;
  /// Non-null when the last play action resulted in an error (e.g. stream failed)
  final String? error;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.playbackQueue = const [],
    this.volume = 1.0,
    this.speed = 1.0,
    this.isShuffle = false,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.sleepTimeRemaining,
    this.error,
  });

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<Song>? queue,
    List<Song>? playbackQueue,
    double? volume,
    double? speed,
    bool? isShuffle,
    AudioServiceRepeatMode? repeatMode,
    Duration? sleepTimeRemaining,
    bool clearSleepTimeRemaining = false,
    String? error,
    bool clearError = false,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      playbackQueue: playbackQueue ?? this.playbackQueue,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      sleepTimeRemaining: clearSleepTimeRemaining
          ? null
          : (sleepTimeRemaining ?? this.sleepTimeRemaining),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final repository = ref.watch(musicRepositoryProvider);
  final localSource = ref.watch(localMusicSourceProvider);
  return PlayerNotifier(
    handler,
    repository,
    localSource,
    ref,
  );
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final MelodriftAudioHandler _handler;
  final MusicRepository _repository;
  final LocalMusicSource _localSource;
  final Ref _ref;
  final _log = AppLogger('PlayerNotifier');
  
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<List<MediaItem>>? _queueSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _bufferedPositionSubscription;

  String? _resolvingVideoId;
  int _playGeneration = 0; // incremented on every new play request to cancel stale resolutions
  Timer? _playbackStateDebounceTimer;
  String? _lastSavedSongId;
  DateTime? _lastSkipTime;
  final Map<String, String> _streamUrlCache = {};

  PlayerNotifier(
    this._handler,
    this._repository,
    this._localSource,
    this._ref,
  ) : super(const PlayerState()) {
    _subscribe();
  }

  void _updatePlaybackQueue() {
    final originalQueue = state.queue;
    if (state.isShuffle) {
      final indices = _handler.effectiveIndices;
      if (indices.length == originalQueue.length) {
        state = state.copyWith(
          playbackQueue: indices.map((i) => originalQueue[i]).toList(),
        );
        return;
      }
    }
    state = state.copyWith(playbackQueue: originalQueue);
  }

  void _subscribe() {
    // 1. Current Song
    _mediaItemSubscription = _handler.mediaItem.listen((item) {
      if (item != null) {
        final song = _mapMediaItemToSong(item);
        state = state.copyWith(
          currentSong: song,
          duration: item.duration ?? Duration.zero,
        );
        unawaited(_resolveNextInQueue()); // Trigger pre-resolution

        if (_lastSavedSongId != song.id) {
          _lastSavedSongId = song.id;
          _addToHistory(song);
        }
      }
    });

    // 2. Playback State
    _playbackStateSubscription = _handler.playbackState.listen((pState) {
      if (pState.processingState == AudioProcessingState.completed) {
        final now = DateTime.now();
        final hasSkippedRecently = _lastSkipTime != null && now.difference(_lastSkipTime!) < const Duration(milliseconds: 1000);
        if (state.isLoading || _resolvingVideoId != null || hasSkippedRecently) {
          _log.info('Playback state completed event ignored (already loading/resolving or skipped recently).');
          return;
        }
        _lastSkipTime = now;
        _log.info('Playback state is completed. Auto-advancing to next song.');
        next();
        return;
      }
      final isBufferingOrLoading = pState.processingState == AudioProcessingState.buffering ||
                                   pState.processingState == AudioProcessingState.loading;
      final targetPlaying = (_resolvingVideoId != null) ? state.isPlaying : pState.playing;
      final showLoading = _resolvingVideoId != null || (!targetPlaying && isBufferingOrLoading);

      // If the player says it is NOT playing, but we currently think it is playing,
      // we debounce the update to false by 200ms to filter out transient stutters.
      if (!targetPlaying && state.isPlaying) {
        _playbackStateDebounceTimer?.cancel();
        _playbackStateDebounceTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            state = state.copyWith(
              isPlaying: false,
              isLoading: showLoading,
              position: pState.updatePosition,
              bufferedPosition: pState.bufferedPosition,
              speed: pState.speed,
            );
            _updatePlaybackQueue();
          }
        });
      } else {
        _playbackStateDebounceTimer?.cancel();
        state = state.copyWith(
          isPlaying: targetPlaying,
          isLoading: showLoading,
          position: pState.updatePosition,
          bufferedPosition: pState.bufferedPosition,
          speed: pState.speed,
        );
        _updatePlaybackQueue();
      }
    });


    // 3. Queue
    _queueSubscription = _handler.queue.listen((mItems) {
      state = state.copyWith(
        queue: mItems.map(_mapMediaItemToSong).toList(),
      );
      _updatePlaybackQueue();
    });

    // 4. Real-time Streams for player timeline
    _positionSubscription = _handler.positionStream
      .listen((pos) {
        state = state.copyWith(position: pos);
      });

    // 5. Duration
    _durationSubscription = _handler.durationStream
      .listen((dur) {
        if (dur != null) {
          state = state.copyWith(duration: dur);
        }
      });

    _bufferedPositionSubscription = _handler.bufferedPositionStream
      .listen((bufPos) {
        state = state.copyWith(bufferedPosition: bufPos);
      });
  }

  Future<void> _addToHistory(Song song) async {
    try {
      final record = ListeningHistoryRecord()
        ..songId = song.id
        ..title = song.title
        ..artist = song.artist
        ..artworkUrl = song.artworkUrl
        ..playedAt = DateTime.now();
      await _localSource.saveListeningHistoryRecord(record);
      _log.info('Saved song to history: ${song.title}');
      _ref.invalidate(listeningHistoryProvider);

      // Track analytics & taste profile
      try {
        unawaited(_ref.read(analyticsServiceProvider).logSongPlayed(song));
        unawaited(_ref.read(tasteProfilerServiceProvider).recordPlayEvent(
          song: song,
          playedDuration: state.position,
          totalDuration: state.duration,
          isSkipped: false,
        ));
      } catch (_) {}
    } catch (e, st) {
      _log.error('Failed to save song to history', e, st);
    }
  }

  // --- Mappings ---

  MediaItem _mapSongToMediaItem(
    Song song, {
    String? streamUrl,
  }) {
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
        'source': song.source,
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
      videoId: item.extras?['videoId'] as String? ?? item.id,
      streamUrl: item.extras?['streamUrl'] as String?,
      source: item.extras?['source'] as String? ?? 'JioSaavn',
    );

  }


  Future<String> _resolveStream(String videoId, {Song? song}) async {
    try {
      final lookupId = song?.id ?? videoId;

      // 1. Instant Cache Hit (0ms playback)
      if (_streamUrlCache.containsKey(lookupId) && _streamUrlCache[lookupId]!.isNotEmpty) {
        _log.info('Instant stream resolution from memory cache for $lookupId');
        return _streamUrlCache[lookupId]!;
      }
      
      // 2. Check local download
      final localSong = await _localSource.getSong(lookupId);
      if (localSong != null && localSong.isDownloaded && localSong.filePath != null) {
        final file = File(localSong.filePath!);
        if (await file.exists()) {
          _log.info('Playing local download: ${localSong.filePath}');
          _streamUrlCache[lookupId] = localSong.filePath!;
          return localSong.filePath!;
        }
      }

      // 3. Unified Stream Resolver (Tier 1 JioSaavn Matcher -> Tier 2 YouTube Direct -> Tier 3 Piped -> Tier 4 Vercel)
      final resolver = getIt<UnifiedStreamResolver>();
      final result = await resolver.resolve(song: song, videoId: videoId, quality: 'High');
      if (result != null && result.url.isNotEmpty) {
        _streamUrlCache[lookupId] = result.url;
        _log.info('Resolved stream via ${result.source} (${result.bitrate ?? 128}kbps) for $lookupId');
        return result.url;
      }

      // 4. Final repository fallback
      final repoUrl = await _repository.getStreamUrl(videoId, quality: 'High').timeout(const Duration(seconds: 6), onTimeout: () => '');
      if (repoUrl.isNotEmpty) {
        _streamUrlCache[lookupId] = repoUrl;
        return repoUrl;
      }

      return '';
    } catch (e, stackTrace) {
      _log.error('Error resolving stream for videoId $videoId: $e', e, stackTrace);
      return '';
    }
  }

  // Pre-resolve next song in queue
  Future<void> _resolveNextInQueue() async {
    // Removed gapless early return to ensure stream URLs are always fetched


    final currentSong = state.currentSong;
    if (currentSong == null || state.queue.isEmpty) return;

    final currentIndex = state.queue.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) return;

    final playOrder = _handler.effectiveIndices;
    if (playOrder.isEmpty) return;

    final currentPos = playOrder.indexOf(currentIndex);
    if (currentPos == -1) return;

    final songsToResolve = <int>[];
    for (int i = 1; i <= 2; i++) {
      final nextPos = currentPos + i;
      int targetIndex;
      if (nextPos < playOrder.length) {
        targetIndex = playOrder[nextPos];
      } else if (state.repeatMode == AudioServiceRepeatMode.all) {
        targetIndex = playOrder[nextPos % playOrder.length];
      } else {
        continue;
      }

      final song = state.queue[targetIndex];
      if (song.streamUrl == null || song.streamUrl!.isEmpty) {
        songsToResolve.add(targetIndex);
      }
    }

    if (songsToResolve.isEmpty) {
      _log.debug('Next songs in sequence already resolved, skipping prefetch');
      return;
    }

    _log.debug('Prefetching ${songsToResolve.length} sequence-next songs at indexes: $songsToResolve');

    // Resolve all in parallel for speed
    final futures = <Future<({int index, String url})>>[];
    for (final index in songsToResolve) {
      final song = state.queue[index];
      futures.add(
        _resolveStream(song.videoId, song: song).then((url) => (index: index, url: url)),
      );
    }

    try {
      final results = await Future.wait(futures);
      
      // Update queue with resolved URLs
      final updatedQueue = List<MediaItem>.from(_handler.queue.value);
      for (final result in results) {
        if (result.url.isNotEmpty && result.index < updatedQueue.length) {
          final extras = Map<String, dynamic>.from(updatedQueue[result.index].extras ?? {});
          extras['streamUrl'] = result.url;
          updatedQueue[result.index] = updatedQueue[result.index].copyWith(extras: extras);
          _log.debug('Prefetched sequence song: ${state.queue[result.index].title}');
        }
      }

      if (results.isNotEmpty) {
        final currentPlayingIndex = state.queue.indexWhere((s) => s.id == currentSong.id);
        await _handler.updateQueue(
          updatedQueue,
          initialIndex: currentPlayingIndex >= 0 ? currentPlayingIndex : 0,
        );
      }
    } catch (e, st) {
      _log.error('Error during prefetch', e, st);
    }
  }

  bool _isExplicit(Song song) {
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    final album = song.album.toLowerCase();
    return title.contains('explicit') ||
        title.contains('parental advisory') ||
        artist.contains('explicit') ||
        album.contains('explicit');
  }

  // --- Playback Commands ---

  Future<void> playSong(Song song) async {
    _lastSkipTime = DateTime.now();
    _log.debug('playSong requested for: ${song.title} (${song.videoId})');

    final allowExplicit = _ref.read(allowExplicitContentProvider);
    if (!allowExplicit && _isExplicit(song)) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('"${song.title}" contains explicit content and is restricted in settings.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _resolvingVideoId = song.videoId;
    final generation = ++_playGeneration; // stamp this request

    // 1. Instantly update Riverpod state so UI (artwork, title, spinner) updates immediately
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
    );

    // 2. Instantly push metadata to audio handler streams for other listening widgets
    final tempItem = _mapSongToMediaItem(song);
    _handler.mediaItem.add(tempItem);
    _handler.queue.add([tempItem]);

    try {
      // 3. Resolve the stream URL asynchronously
      final streamUrl = await _resolveStream(song.videoId, song: song);

      // Stale check: user tapped another song while we were resolving
      if (generation != _playGeneration) {
        _log.info('playSong: stale resolution for "${song.title}" discarded (generation $generation < $_playGeneration)');
        return;
      }

      if (streamUrl.isEmpty) {
        throw StateError('Unable to resolve a playable stream for ${song.title}');
      }
      _log.debug('streamUrl for playback resolved: "$streamUrl"');

      final mediaItem = _mapSongToMediaItem(song, streamUrl: streamUrl);
      _log.debug('updating queue with final media item: ${mediaItem.title}');
      await _handler.updateQueue([mediaItem], initialIndex: 0);

      _resolvingVideoId = null;
      state = state.copyWith(isLoading: false, isPlaying: true);

      _log.debug('invoking handler.play()');
      await _handler.play();
      _log.debug('handler.play() completed successfully');
    } catch (e) {
      if (generation != _playGeneration) return; // stale, ignore
      _log.error('Error calling handler.play(): $e', e);
      state = state.copyWith(isLoading: false, isPlaying: false);
    } finally {
      if (generation == _playGeneration) _resolvingVideoId = null;
    }
  }

  Future<void> playQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _lastSkipTime = DateTime.now();

    final allowExplicit = _ref.read(allowExplicitContentProvider);
    List<Song> filteredSongs = songs;
    int targetIndex = initialIndex;

    if (!allowExplicit) {
      filteredSongs = songs.where((s) => !_isExplicit(s)).toList();
      if (filteredSongs.isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('All songs in this list contain explicit content and are restricted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      // Re-map the initialIndex to the filtered list
      targetIndex = filteredSongs.indexWhere((s) => s.id == songs[initialIndex].id);
      if (targetIndex == -1) targetIndex = 0;
    }

    final selectedSong = filteredSongs[targetIndex];
    _resolvingVideoId = selectedSong.videoId;
    final generation = ++_playGeneration; // stamp this request

    // 1. Instantly update Riverpod state so UI updates immediately
    state = state.copyWith(
      currentSong: selectedSong,
      queue: filteredSongs,
      isLoading: true,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
    );

    // 2. Instantly push metadata to audio handler streams
    final tempItems = filteredSongs.map((s) => _mapSongToMediaItem(s)).toList();
    _handler.mediaItem.add(tempItems[targetIndex]);
    _handler.queue.add(tempItems);

    try {
      // 3. Resolve the stream URL asynchronously
      final resolvedFirstUrl = await _resolveStream(selectedSong.videoId, song: selectedSong);

      if (generation != _playGeneration) {
        _log.info('playQueue: stale resolution for "${selectedSong.title}" discarded');
        return;
      }

      if (resolvedFirstUrl.isEmpty) {
        _log.error('Unable to resolve stream for "${selectedSong.title}". Both JioSaavn and YouTube failed.');
        state = state.copyWith(
          isLoading: false,
          isPlaying: false,
          error: 'Could not load stream for "${selectedSong.title}". Check your internet connection.',
        );
        return;
      }

      final mItems = <MediaItem>[];
      for (int i = 0; i < filteredSongs.length; i++) {
        if (i == targetIndex) {
          mItems.add(_mapSongToMediaItem(filteredSongs[i], streamUrl: resolvedFirstUrl));
        } else {
          mItems.add(_mapSongToMediaItem(filteredSongs[i]));
        }
      }

      await _handler.updateQueue(mItems, initialIndex: targetIndex);
      _resolvingVideoId = null;
      state = state.copyWith(isLoading: false, isPlaying: true);
      await _handler.play();
    } catch (e) {
      if (generation != _playGeneration) return;
      _log.error('Error in playQueue: $e', e);
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'Playback error: $e',
      );
    } finally {
      if (generation == _playGeneration) _resolvingVideoId = null;
    }
  }


  Future<void> togglePlay() async {
    final nextPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextPlaying);
    try {
      if (!nextPlaying) {
        await _handler.pause();
      } else {
        await _handler.play();
      }
    } catch (e) {
      _log.error('Error toggling playback: $e', e);
      // Revert state if it failed
      state = state.copyWith(isPlaying: !nextPlaying);
    }
  }

  Future<void> next() async {
    final currentSong = state.currentSong;
    if (currentSong == null || state.queue.isEmpty) return;

    final currentIndex = state.queue.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) return;

    int targetIndex;
    if (state.isShuffle) {
      if (state.queue.length <= 1) return;
      final random = math.Random();
      int nextIdx = random.nextInt(state.queue.length);
      if (nextIdx == currentIndex) {
        nextIdx = (nextIdx + 1) % state.queue.length;
      }
      targetIndex = nextIdx;
    } else {
      final nextIdx = currentIndex + 1;
      if (nextIdx < state.queue.length) {
        targetIndex = nextIdx;
      } else if (state.repeatMode == AudioServiceRepeatMode.all) {
        targetIndex = 0;
      } else {
        // Check if autoplay infinite radio is enabled
        final isAutoplay = _ref.read(autoplayEnabledProvider);
        if (isAutoplay) {
          _log.info('Queue ended. Fetching autoplay recommendations...');
          try {
            final recs = await _ref.read(recommendationServiceProvider).getAutoplayQueue(currentSong);
            if (recs.isNotEmpty) {
              await addSongsToQueue(recs);
              await skipToQueueItem(currentIndex + 1);
              return;
            }
          } catch (e) {
            _log.error('Failed to load autoplay recommendations: $e');
          }
        }
        return; // End of queue
      }
    }

    await skipToQueueItem(targetIndex);
  }

  Future<void> previous() async {
    final currentSong = state.currentSong;
    if (currentSong == null || state.queue.isEmpty) return;

    final currentIndex = state.queue.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) return;

    int targetIndex;
    if (state.isShuffle) {
      if (state.queue.length <= 1) return;
      final random = math.Random();
      int prevIdx = random.nextInt(state.queue.length);
      if (prevIdx == currentIndex) {
        prevIdx = (prevIdx + 1) % state.queue.length;
      }
      targetIndex = prevIdx;
    } else {
      final prevIdx = currentIndex - 1;
      if (prevIdx >= 0) {
        targetIndex = prevIdx;
      } else if (state.repeatMode == AudioServiceRepeatMode.all) {
        targetIndex = state.queue.length - 1;
      } else {
        // Seek to beginning of current song
        await seek(Duration.zero);
        return;
      }
    }

    await skipToQueueItem(targetIndex);
  }

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
    // Cycles through Repeat Modes: Off (none) -> Repeat All (all) -> Repeat One (one) -> Off (none)
    AudioServiceRepeatMode nextMode;
    switch (state.repeatMode) {
      case AudioServiceRepeatMode.none:
        nextMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        nextMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        nextMode = AudioServiceRepeatMode.none;
        break;
    }
    await _handler.setRepeatMode(nextMode);
    state = state.copyWith(repeatMode: nextMode);
  }

  Future<void> skipToQueueItem(int originalIndex) async {
    if (originalIndex < 0 || originalIndex >= state.queue.length) return;
    _lastSkipTime = DateTime.now();
    final song = state.queue[originalIndex];
    _resolvingVideoId = song.videoId;

    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      position: Duration.zero,
      duration: Duration.zero,
    );

    try {
      final streamUrl = await _resolveStream(song.videoId, song: song);
      if (streamUrl.isEmpty) {
        throw StateError('Unable to resolve a playable stream for ${song.title}');
      }
      if (streamUrl.isNotEmpty) {
        final updatedQueue = List<MediaItem>.from(_handler.queue.value);
        if (originalIndex < updatedQueue.length) {
          final extras = Map<String, dynamic>.from(updatedQueue[originalIndex].extras ?? {});
          extras['streamUrl'] = streamUrl;
          updatedQueue[originalIndex] = updatedQueue[originalIndex].copyWith(extras: extras);
          await _handler.updateQueue(updatedQueue, initialIndex: originalIndex);
        }
      }

      await _handler.skipToQueueItem(originalIndex);
      await _handler.play();
    } catch (e) {
      _log.error('Error in skipToQueueItem: $e', e);
      state = state.copyWith(isLoading: false, isPlaying: false);
    } finally {
      _resolvingVideoId = null;
    }
  }

  Future<void> removeFromQueue(Song song) async {
    final mediaItem = _mapSongToMediaItem(song);
    await _handler.removeQueueItem(mediaItem);
  }

  /// Add a single song to the end of the current queue
  Future<void> addToQueue(Song song) async {
    final mediaItem = _mapSongToMediaItem(song);
    final currentQueue = List<MediaItem>.from(_handler.queue.value);
    currentQueue.add(mediaItem);
    await _handler.updateQueue(currentQueue);
    
    // Update local state to include the new song
    state = state.copyWith(
      queue: [...state.queue, song],
    );
  }

  /// Add multiple songs to the end of the current queue
  Future<void> addSongsToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final mediaItems = songs.map((s) => _mapSongToMediaItem(s)).toList();
    final currentQueue = List<MediaItem>.from(_handler.queue.value);
    currentQueue.addAll(mediaItems);
    await _handler.updateQueue(currentQueue);
    
    // Update local state
    state = state.copyWith(
      queue: [...state.queue, ...songs],
    );
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    await _handler.moveQueueItem(oldIndex, newIndex);
    _updatePlaybackQueue();
  }

  Timer? _sleepTimer;
  Timer? _sleepCountdownTimer;

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();

    if (duration == null) {
      state = state.copyWith(clearSleepTimeRemaining: true);
      return;
    }

    state = state.copyWith(sleepTimeRemaining: duration);

    _sleepTimer = Timer(duration, () {
      _handler.pause();
      setSleepTimer(null);
    });

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.sleepTimeRemaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        timer.cancel();
      } else {
        state = state.copyWith(sleepTimeRemaining: remaining - const Duration(seconds: 1));
      }
    });
  }

  void cancelSleepTimer() {
    setSleepTimer(null);
  }


  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();
    _playbackStateDebounceTimer?.cancel();
    _mediaItemSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _queueSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferedPositionSubscription?.cancel();
    super.dispose();
  }
}

