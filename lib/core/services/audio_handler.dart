import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

final audioHandlerProvider = Provider<MelodriftAudioHandler>((ref) {
  throw UnimplementedError('MelodriftAudioHandler is not initialized yet. Override audioHandlerProvider in ProviderScope.');
});

class MelodriftAudioHandler extends BaseAudioHandler with QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  final List<MediaItem> _currentQueue = [];
  final List<int> _playableQueueIndices = [];
  final _log = AppLogger('AudioHandler');

  double _userVolume = 1.0;
  bool _isFadingOut = false;

  /// Fades the volume from current level to target level over a duration
  Future<void> _fadeVolume(double targetVolume, Duration duration) async {
    const steps = 8;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final startVolume = _player.volume;
    final scaledTarget = targetVolume * _userVolume;
    final volumeDiff = scaledTarget - startVolume;

    for (int i = 1; i <= steps; i++) {
      final currentTarget = startVolume + (volumeDiff * (i / steps));
      await _player.setVolume(currentTarget.clamp(0.0, 1.0));
      await Future<void>.delayed(stepDuration);
    }
  }
  
  /// Hash of the current queue to avoid redundant syncs
  String _queueHash = '';
  
  /// Generate hash for queue to detect meaningful changes
  static String _generateQueueHash(List<MediaItem> queue) {
    if (queue.isEmpty) return '';
    return queue
        .map((item) => '${item.id}:${item.title}:${item.artist}:${item.duration}:${item.artUri}:${item.extras?['streamUrl'] ?? ''}')
        .join('|');
  }

  MelodriftAudioHandler() {
    _init();
  }

  void _updatePlaybackState() {
    playbackState.add(_transformEvent());
  }

  void _init() {
    _playlist = ConcatenatingAudioSource(children: []);
    
    // Defer setAudioSource until syncPlaylist has items to prevent Windows hang

    // 1. Listen to all relevant player streams to update playbackState
    _player.playbackEventStream.listen(
      (event) {
        _log.debug('Playback event: playing=${_player.playing}, state=${_player.processingState}, position=${_player.position}');
        _updatePlaybackState();
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.error('Playback event stream error: $error', error, stackTrace);
        _updatePlaybackState();
      },
    );

    _player.playingStream.listen((playing) {
      _log.debug('playingStream: $playing');
      _updatePlaybackState();
    });

    _player.processingStateStream.listen((state) async {
      _log.debug('processingStateStream: $state');
      _updatePlaybackState();
      if (state == ProcessingState.completed) {
        await _handleTrackCompleted();
      }
    });

    _player.speedStream.listen((speed) {
      _log.debug('speedStream: $speed');
      _updatePlaybackState();
    });

    _player.loopModeStream.listen((loopMode) {
      _log.debug('loopModeStream: $loopMode');
      _updatePlaybackState();
    });

    _player.shuffleModeEnabledStream.listen((shuffleEnabled) {
      _log.debug('shuffleModeEnabledStream: $shuffleEnabled');
      _updatePlaybackState();
    });

    // 2. Listen to index changes to update mediaItem
    _player.currentIndexStream.listen((index) async {
      _log.debug('Current index changed to: $index');
      final queueIndex = _queueIndexForPlayerIndex(index);
      if (queueIndex != null && queue.value.isNotEmpty && queueIndex < queue.value.length) {
        mediaItem.add(queue.value[queueIndex]);

        // Crossfade: Fade in the new track
        final prefs = await SharedPreferences.getInstance();
        final crossfade = prefs.getBool('crossfade_enabled') ?? false;
        if (crossfade && _player.playing) {
          await _player.setVolume(0.0);
          await _fadeVolume(1.0, const Duration(milliseconds: 600));
        }
      }
    });

    // Crossfade position monitoring
    _player.positionStream.listen((position) async {
      final duration = _player.duration;
      if (duration == null || duration == Duration.zero) return;

      final prefs = await SharedPreferences.getInstance();
      final crossfade = prefs.getBool('crossfade_enabled') ?? false;
      if (!crossfade) return;

      final remaining = duration - position;
      if (remaining <= const Duration(seconds: 3) && !_isFadingOut && _player.playing) {
        _isFadingOut = true;
        _log.debug('Crossfade: Nearing end of track. Fading out volume...');
        await _fadeVolume(0.0, const Duration(milliseconds: 2500));
        
        await _player.setVolume(_userVolume);
        _isFadingOut = false;
      }
    });

    // 3. Update duration dynamically when resolved by player
    _player.durationStream.listen((duration) {
      _log.debug('Player duration resolved: $duration');
      if (duration != null) {
        final currentItem = mediaItem.value;
        if (currentItem != null && currentItem.duration != duration) {
          final updatedItem = currentItem.copyWith(duration: duration);
          mediaItem.add(updatedItem);

          // Also update this item in the queue so the playlist keeps the duration
          final index = _queueIndexForPlayerIndex(_player.currentIndex);
          if (index != null && index < queue.value.length) {
            final updatedQueue = List<MediaItem>.from(queue.value);
            updatedQueue[index] = updatedQueue[index].copyWith(duration: duration);
            queue.add(updatedQueue);
          }
        }
      }
    });
  }

  PlaybackState _transformEvent() {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _queueIndexForPlayerIndex(_player.currentIndex),
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode] ?? AudioServiceRepeatMode.none,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  // --- Playback Controls ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.length == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final crossfade = prefs.getBool('crossfade_enabled') ?? false;

    if (crossfade && _player.playing) {
      await _fadeVolume(0.0, const Duration(milliseconds: 400));
    }

    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_player.loopMode == LoopMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }

    if (crossfade && _player.playing) {
      await _fadeVolume(1.0, const Duration(milliseconds: 400));
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.length == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final crossfade = prefs.getBool('crossfade_enabled') ?? false;

    if (crossfade && _player.playing) {
      await _fadeVolume(0.0, const Duration(milliseconds: 400));
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }

    if (crossfade && _player.playing) {
      await _fadeVolume(1.0, const Duration(milliseconds: 400));
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_player.loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final gaplessEnabled = prefs.getBool('gapless_playback') ?? true;
    if (!gaplessEnabled) {
      await _player.pause();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    if (_player.hasNext || _player.loopMode == LoopMode.all) {
      await skipToNext();
      return;
    }

    await _player.pause();
    await _player.seek(Duration.zero);
    _updatePlaybackState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final playerIndex = _playerIndexForQueueIndex(index);
    if (playerIndex == null) {
      _log.warning('Queue item $index has no playable source yet; skip request ignored until resolved.');
      return;
    }
    await _player.seek(Duration.zero, index: playerIndex);
  }

  // --- Queue Management ---

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final currentQueue = queue.value;
    queue.add([...currentQueue, mediaItem]);
    await _syncPlaylist(queue.value);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final currentQueue = queue.value;
    queue.add([...currentQueue, ...mediaItems]);
    await _syncPlaylist(queue.value);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final currentQueue = queue.value;
    final index = currentQueue.indexWhere((item) => item.id == mediaItem.id);
    if (index != -1) {
      final updatedQueue = List<MediaItem>.from(currentQueue)..removeAt(index);
      queue.add(updatedQueue);
      await _syncPlaylist(queue.value);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue, {int initialIndex = 0}) async {
    this.queue.add(queue);
    await _syncPlaylist(queue, initialIndex: initialIndex);
  }

  AudioSource _createAudioSource(MediaItem item) {
    final streamUrl = item.extras?['streamUrl'] as String?;
    
    _log.debug('Creating AudioSource for MediaItem: ${item.title}, id: ${item.id}, streamUrl: "${streamUrl != null && streamUrl.length > 80 ? '${streamUrl.substring(0, 80)}...' : streamUrl}"');
    
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final isNetworkUrl = streamUrl.startsWith('http://') || streamUrl.startsWith('https://');
      if (isNetworkUrl) {
        // Warn about WebM/Opus URLs — just_audio_windows (WMF) cannot play them.
        // This should not happen after the stream filter fix, but guard defensively.
        final lowerUrl = streamUrl.toLowerCase();
        if (lowerUrl.contains('mime=audio%2Fwebm') ||
            lowerUrl.contains('mime=audio/webm') ||
            lowerUrl.contains('codecs=opus')) {
          _log.warning('⚠️ WebM/Opus URL detected for "${item.title}" — WMF (Windows) cannot decode this. Stream filter may need updating.');
        }
        return AudioSource.uri(
          Uri.parse(streamUrl),
          tag: item,   // tag enables item-level error correlation
        );
      } else {
        // Local file path
        return AudioSource.file(streamUrl, tag: item);
      }
    }
    throw StateError('Cannot create AudioSource without streamUrl for ${item.title}');
  }

  bool _hasPlayableSource(MediaItem item) {
    final streamUrl = item.extras?['streamUrl'] as String?;
    return streamUrl != null && streamUrl.isNotEmpty;
  }

  int? _queueIndexForPlayerIndex(int? playerIndex) {
    if (playerIndex == null || playerIndex < 0 || playerIndex >= _playableQueueIndices.length) {
      return null;
    }
    return _playableQueueIndices[playerIndex];
  }

  int? _playerIndexForQueueIndex(int queueIndex) {
    final playerIndex = _playableQueueIndices.indexOf(queueIndex);
    return playerIndex == -1 ? null : playerIndex;
  }

  ({List<MediaItem> items, List<int> queueIndices}) _playableEntries(List<MediaItem> items) {
    final playableItems = <MediaItem>[];
    final queueIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (_hasPlayableSource(items[i])) {
        playableItems.add(items[i]);
        queueIndices.add(i);
      }
    }
    return (items: playableItems, queueIndices: queueIndices);
  }


  Future<void> _syncPlaylist(List<MediaItem> newQueue, {int initialIndex = 0}) async {
    _log.debug('_syncPlaylist invoked with ${newQueue.length} items (initialIndex: $initialIndex)');
    
    // Check if queue has actually changed using hash
    final newHash = _generateQueueHash(newQueue);
    if (newHash == _queueHash && newQueue.length == _currentQueue.length) {
      _log.debug('Queue unchanged (hash match), skipping sync');
      return;
    }
    
    if (newQueue.isEmpty) {
      _log.debug('Queue is empty, clearing playlist');
      await _playlist.clear();
      _currentQueue.clear();
      _playableQueueIndices.clear();
      _queueHash = '';
      return;
    }

    final playable = _playableEntries(newQueue);
    if (playable.items.isEmpty) {
      _log.debug('Queue has no playable stream URLs yet; keeping metadata queue and clearing native playlist');
      await _playlist.clear();
      _currentQueue
        ..clear()
        ..addAll(newQueue);
      _playableQueueIndices.clear();
      _queueHash = newHash;
      final metadataIndex = initialIndex.clamp(0, newQueue.length - 1).toInt();
      mediaItem.add(newQueue[metadataIndex]);
      return;
    }

    final currentLength = _playlist.length;
    _log.debug('Current playlist length: $currentLength');
    try {
      _log.debug('Overwriting playlist with ${playable.items.length} playable items from ${newQueue.length} queued items, initialIndex: $initialIndex');
      final prefs = await SharedPreferences.getInstance();
      final gaplessEnabled = prefs.getBool('gapless_playback') ?? true;
      
      _playlist = ConcatenatingAudioSource(
        useLazyPreparation: gaplessEnabled,
        children: playable.items.map(_createAudioSource).toList(),
      );
      final validQueueIndex = (initialIndex >= 0 && initialIndex < newQueue.length) ? initialIndex : playable.queueIndices.first;
      final validPlayerIndex = playable.queueIndices.indexOf(validQueueIndex);
      _playableQueueIndices
        ..clear()
        ..addAll(playable.queueIndices);
      await _player.setAudioSource(
        _playlist,
        initialIndex: validPlayerIndex == -1 ? 0 : validPlayerIndex,
        initialPosition: Duration.zero,
      );
      
      _currentQueue.clear();
      _currentQueue.addAll(newQueue);
      _playableQueueIndices
        ..clear()
        ..addAll(playable.queueIndices);
      _queueHash = newHash; // Cache the new hash

      // Force update mediaItem to ensure UI gets the new track metadata in real-time
      final index = _queueIndexForPlayerIndex(_player.currentIndex);
      if (index != null && index < newQueue.length) {
        _log.debug('Post-sync: Pushing active MediaItem at index $index: ${newQueue[index].title}');
        mediaItem.add(newQueue[index]);
      } else if (newQueue.isNotEmpty) {
        _log.debug('Post-sync: Pushing first MediaItem in queue: ${newQueue.first.title}');
        mediaItem.add(newQueue.first);
      }
      
      _log.debug('Playlist sync completed successfully. Current playlist length now: ${_playlist.length}');
    } catch (e, stack) {
      _log.error('ERROR syncing playlist: $e', e, stack);
    }
  }

  // --- Stream Getters ---

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  
  List<int> get effectiveIndices {
    final indices = _player.effectiveIndices;
    if (indices == null) return List<int>.from(_playableQueueIndices);
    return indices
        .where((index) => index >= 0 && index < _playableQueueIndices.length)
        .map((index) => _playableQueueIndices[index])
        .toList();
  }

  // --- Audio Parameters ---

  Future<void> setVolume(double volume) async {
    _userVolume = volume;
    await _player.setVolume(volume);
  }

  Future<void> setPlaybackSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    LoopMode loopMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        loopMode = LoopMode.off;
        break;
      case AudioServiceRepeatMode.one:
        loopMode = LoopMode.one;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        loopMode = LoopMode.all;
        break;
    }
    await _player.setLoopMode(loopMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enable = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enable);
  }

  Future<void> moveQueueItem(int fromIndex, int toIndex) async {
    final currentQueue = queue.value;
    if (fromIndex < 0 || fromIndex >= currentQueue.length) return;
    if (toIndex < 0 || toIndex >= currentQueue.length) return;

    final updatedQueue = List<MediaItem>.from(currentQueue);
    final item = updatedQueue.removeAt(fromIndex);
    updatedQueue.insert(toIndex, item);
    queue.add(updatedQueue);

    _currentQueue.clear();
    _currentQueue.addAll(updatedQueue);

    await _syncPlaylist(updatedQueue);
  }
}

