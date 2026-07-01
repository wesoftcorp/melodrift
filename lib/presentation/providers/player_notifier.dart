import 'dart:async';
import 'dart:io';
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
import '../../core/services/audio_quality_preferences.dart';
import '../../core/utils/logger.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/jiosaavn_service.dart';
import '../../core/services/music_track.dart';
import '../../core/utils/matching_engine.dart';
import '../screens/settings_screen.dart' show allowExplicitContentProvider, gaplessPlaybackProvider;
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
  Timer? _playbackStateDebounceTimer;
  String? _lastSavedSongId;

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
      final isBufferingOrLoading = pState.processingState == AudioProcessingState.buffering ||
                                   pState.processingState == AudioProcessingState.loading;
      final showLoading = _resolvingVideoId != null || isBufferingOrLoading;
      final targetPlaying = showLoading ? state.isPlaying : pState.playing;

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
              isShuffle: pState.shuffleMode != AudioServiceShuffleMode.none,
              repeatMode: pState.repeatMode,
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
          isShuffle: pState.shuffleMode != AudioServiceShuffleMode.none,
          repeatMode: pState.repeatMode,
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


  Future<String> _resolveStream(String videoId, {Song? song}) async {
    try {
      _log.debug('Resolving stream for videoId: $videoId');
      
      // Check if downloaded locally first using the original song.id to prevent query-matching failures
      final lookupId = song?.id ?? videoId;
      final localSong = await _localSource.getSong(lookupId);
      if (localSong != null && localSong.isDownloaded && localSong.filePath != null) {
        final file = File(localSong.filePath!);
        if (await file.exists()) {
          _log.info('Playing local download: ${localSong.filePath}');
          return localSong.filePath!;
        }
      }

      // Direct JioSaavn stream resolution if song is from JioSaavn
      if (song != null && song.source.toLowerCase().contains('jiosaavn')) {
        _log.info('Resolving JioSaavn stream directly using ID: ${song.id}');
        final url = await _repository.getStreamUrl(song.id);
        if (url.isNotEmpty) {
          return url;
        }
      }

      String targetVideoId = videoId;
      final isYouTube = song != null && song.source.toLowerCase().contains('youtube');
      if (song != null && !isYouTube) {
        final resolvedSong = await _ensureYouTubeVideoId(song);
        targetVideoId = resolvedSong.videoId;
      }

      // Try JioSaavn matching first for 320kbps audio stream (only for YouTube songs)
      if (song != null && isYouTube) {
        try {
          // YouTube song titles often contain full descriptions like:
          // "Vaaste Song: Dhvani Bhanushali, Tanishk Bagchi | T-Series"
          // Strip everything after ':' or '|' to get a clean search query.
          String cleanTitle = song.title;
          final colonIdx = cleanTitle.indexOf(':');
          if (colonIdx > 0) cleanTitle = cleanTitle.substring(0, colonIdx).trim();
          final pipeIdx = cleanTitle.indexOf('|');
          if (pipeIdx > 0) cleanTitle = cleanTitle.substring(0, pipeIdx).trim();

          // Also clean artist — use only first artist if multiple separated by ,
          final cleanArtist = song.artist.split(',').first.trim();

          final searchQuery = cleanTitle.trim();
          _log.debug('Attempting JioSaavn stream resolution for YouTube song. Query: "$searchQuery"');
          final jioSaavn = getIt<JioSaavnService>();
          final candidates = await jioSaavn.search(searchQuery);
          if (candidates.isNotEmpty) {
            final ytTrack = MusicTrack(
              id: song.videoId,
              title: cleanTitle,   // use cleaned title for matching
              artist: cleanArtist,
              album: song.album,
              duration: song.duration,
              artworkUrl: song.artworkUrl,
              source: 'youtube',
            );
            final match = findMatchingSaavnTrack(ytTrack, candidates);
            if (match != null) {
              _log.info('Matching JioSaavn track found: ${match.title} by ${match.artist}');
              final saavnUrl = await jioSaavn.getStreamUrl(match.id);
              if (saavnUrl != null && saavnUrl.isNotEmpty) {
                _log.info('Successfully resolved JioSaavn 320kbps stream URL');
                return saavnUrl;
              }
            } else {
              _log.debug('No JioSaavn match for "$cleanTitle" within duration tolerance');
            }
          }
        } catch (e) {
          _log.warning('JioSaavn stream resolution failed (falling back to YouTube): $e');
        }
      }

      
      // Fallback to YouTube Music stream
      final quality = (await AudioQualityPreferences.load()).streamingQuality;
      String url = '';
      try {
        url = await _repository
          .getStreamUrl(targetVideoId, quality: quality)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              _log.warning('Stream resolution timeout for $targetVideoId after 15 seconds');
              return '';
            },
          );
      } catch (e) {
        _log.warning('Direct videoId resolution for $targetVideoId failed: $e. Trying YouTube search fallback...');
      }

      // If direct resolution failed, attempt automatic search-based fallback using title & artist
      if (url.isEmpty && song != null) {
        String cleanTitle = song.title;
        final colonIdx = cleanTitle.indexOf(':');
        if (colonIdx > 0) cleanTitle = cleanTitle.substring(0, colonIdx).trim();
        final pipeIdx = cleanTitle.indexOf('|');
        if (pipeIdx > 0) cleanTitle = cleanTitle.substring(0, pipeIdx).trim();

        final cleanArtist = song.artist.split(',').first.trim();
        final queryId = '$cleanTitle $cleanArtist'.trim();

        _log.info('Searching YouTube for active mirror of "$queryId"...');
        try {
          url = await _repository
            .getStreamUrl(queryId, quality: quality)
            .timeout(const Duration(seconds: 15));
        } catch (e2) {
          _log.error('YouTube search fallback also failed: $e2');
        }
      }


      if (url.isNotEmpty) {
        _log.debug('Successfully resolved stream URL: $url');
      }
      return url;

    } catch (e, stackTrace) {
      _log.error('Error resolving stream for videoId $videoId: $e', e, stackTrace);
      return '';
    }
  }

  Future<Song> _ensureYouTubeVideoId(Song song) async {
    if (song.source.toLowerCase().contains('youtube')) {
      return song;
    }


    
    // If videoId is not 11 characters (e.g. search suggestions), use title and artist as search key for streamUrl
    _log.info('Non-YouTube videoId "${song.videoId}" detected for ${song.source}. Passing "${song.title} ${song.artist}" to stream resolver.');
    return Song(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artworkUrl: song.artworkUrl,
      videoId: '${song.title} ${song.artist}',
      streamUrl: song.streamUrl,
      source: song.source,
    );
  }

  // Pre-resolve next song in queue for gapless playback
  Future<void> _resolveNextInQueue() async {
    final gapless = _ref.read(gaplessPlaybackProvider);
    if (!gapless) {
      _log.debug('Gapless playback is disabled. Skipping pre-resolution.');
      return;
    }

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
        await _handler.updateQueue(updatedQueue);
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
      // 3. Resolve the stream URL asynchronously in the background
      final streamUrl = song.streamUrl ?? await _resolveStream(song.videoId, song: song);
      if (streamUrl.isEmpty) {
        throw StateError('Unable to resolve a playable stream for ${song.title}');
      }
      _log.debug('streamUrl for playback resolved: "$streamUrl"');
      
      final mediaItem = _mapSongToMediaItem(song, streamUrl: streamUrl);
      _log.debug('updating queue with final media item: ${mediaItem.title}');
      await _handler.updateQueue([mediaItem], initialIndex: 0);
      
      _log.debug('invoking handler.play()');
      await _handler.play();
      _log.debug('handler.play() completed successfully');
    } catch (e) {
      _log.error('Error calling handler.play(): $e', e);
      state = state.copyWith(isLoading: false, isPlaying: false);
    } finally {
      _resolvingVideoId = null;
    }
  }

  Future<void> playQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    final allowExplicit = _ref.read(allowExplicitContentProvider);
    List<Song> filteredSongs = songs;
    int targetIndex = initialIndex;

    if (!allowExplicit) {
      filteredSongs = songs.where((s) => !_isExplicit(s)).toList();
      if (filteredSongs.isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('All songs in the selection contain explicit content and were restricted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      // Re-map the initialIndex to the filtered list
      final selectedSong = songs[initialIndex];
      targetIndex = filteredSongs.indexWhere((s) => s.id == selectedSong.id);
      if (targetIndex == -1) {
        targetIndex = 0;
      }
    }

    final selectedSong = filteredSongs[targetIndex];
    _resolvingVideoId = selectedSong.videoId;

    // 1. Instantly update Riverpod state so UI updates immediately
    state = state.copyWith(
      currentSong: selectedSong,
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
      // 3. Resolve the stream URL asynchronously in the background
      final resolvedFirstUrl = selectedSong.streamUrl ?? await _resolveStream(selectedSong.videoId, song: selectedSong);
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
      await _handler.play();
    } catch (e) {
      _log.error('Error in playQueue: $e', e);
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'Playback error: $e',
      );
    } finally {
      _resolvingVideoId = null;
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
    final song = state.queue[originalIndex];
    _resolvingVideoId = song.videoId;

    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      position: Duration.zero,
      duration: Duration.zero,
    );

    try {
      final streamUrl = song.streamUrl ?? await _resolveStream(song.videoId, song: song);
      if (streamUrl.isEmpty) {
        throw StateError('Unable to resolve a playable stream for ${song.title}');
      }
      if (streamUrl.isNotEmpty) {
        final updatedQueue = List<MediaItem>.from(_handler.queue.value);
        if (originalIndex < updatedQueue.length) {
          final extras = Map<String, dynamic>.from(updatedQueue[originalIndex].extras ?? {});
          extras['streamUrl'] = streamUrl;
          updatedQueue[originalIndex] = updatedQueue[originalIndex].copyWith(extras: extras);
          await _handler.updateQueue(updatedQueue);
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

