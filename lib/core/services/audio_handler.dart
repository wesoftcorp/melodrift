import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

final audioHandlerProvider = Provider<MelodriftAudioHandler>((ref) {
  throw UnimplementedError('MelodriftAudioHandler is not initialized yet. Override audioHandlerProvider in ProviderScope.');
});

class MelodriftAudioHandler extends BaseAudioHandler with QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  late final ConcatenatingAudioSource _playlist;
  final List<MediaItem> _currentQueue = [];
  final _log = AppLogger('AudioHandler');
  
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
    _player.playbackEventStream.listen((event) {
      _log.debug('Playback event: playing=${_player.playing}, state=${_player.processingState}, position=${_player.position}');
      _updatePlaybackState();
    });

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
    _player.currentIndexStream.listen((index) {
      _log.debug('Current index changed to: $index');
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
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
          final index = _player.currentIndex;
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
      queueIndex: _player.currentIndex,
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
    if (_player.hasNext) {
      await _player.seekToNext();
      return;
    }
    if (_player.loopMode == LoopMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.length == 0) return;
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      return;
    }
    await _player.seek(Duration.zero);
  }

  Future<void> _handleTrackCompleted() async {
    if (_player.loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
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
    await _player.seek(Duration.zero, index: index);
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
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
    await _syncPlaylist(queue);
  }

  AudioSource _createAudioSource(MediaItem item) {
    final streamUrl = item.extras?['streamUrl'] as String?;
    final isEncrypted = item.extras?['isEncrypted'] as bool? ?? false;
    
    _log.debug('Mapping MediaItem: ${item.title}, id: ${item.id}, isEncrypted: $isEncrypted, streamUrl: "$streamUrl"');
    
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final isNetworkUrl = streamUrl.startsWith('http://') || streamUrl.startsWith('https://');
      if (isNetworkUrl) {
        return AudioSource.uri(Uri.parse(streamUrl));
      } else if (!isEncrypted) {
        return AudioSource.file(streamUrl);
      } else {
        return AudioSource.file(streamUrl, tag: item.id);
      }
    }
    _log.warning('Empty stream URL for ${item.title}, using fallback silent audio');
    return AudioSource.uri(Uri.parse('https://github.com/anars/blank-audio/raw/master/250-milliseconds-of-silence.mp3'));
  }

  Future<void> _syncPlaylist(List<MediaItem> newQueue) async {
    _log.debug('_syncPlaylist invoked with ${newQueue.length} items');
    
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
      _queueHash = '';
      return;
    }

    final currentLength = _playlist.length;
    _log.debug('Current playlist length: $currentLength');
    
    bool isAppend = currentLength > 0 && currentLength <= newQueue.length && _currentQueue.length >= currentLength;
    if (isAppend) {
      for (int i = 0; i < currentLength; i++) {
        if (_currentQueue[i].id != newQueue[i].id) {
          isAppend = false;
          break;
        }
      }
    }

    _log.debug('Sync mode isAppend: $isAppend');
    try {
      if (isAppend) {
        // 1. Update any existing items whose stream URL changed
        for (int i = 0; i < currentLength; i++) {
          final oldUrl = _currentQueue[i].extras?['streamUrl'] as String?;
          final newUrl = newQueue[i].extras?['streamUrl'] as String?;
          if (oldUrl != newUrl) {
            _log.debug('Replacing source at index $i in append mode: "$oldUrl" -> "$newUrl"');
            final newSource = _createAudioSource(newQueue[i]);
            if (i < _playlist.length) {
              await _playlist.removeAt(i);
              await _playlist.insert(i, newSource);
            }
          }
        }

        // 2. Append new items
        final toAdd = newQueue.sublist(currentLength);
        if (toAdd.isNotEmpty) {
          _log.debug('Appending ${toAdd.length} items to playlist');
          final newSources = toAdd.map(_createAudioSource).toList();
          await _playlist.addAll(newSources);
        }
      } else {
        // Overwrite
        _log.debug('Overwriting playlist with ${newQueue.length} items');
        await _playlist.clear();
        final newSources = newQueue.map(_createAudioSource).toList();
        await _playlist.addAll(newSources);
      }
      
      if (_player.audioSource == null) {
        _log.debug('Setting playlist audio source for the first time');
        await _player.setAudioSource(_playlist);
      }
      
      _currentQueue.clear();
      _currentQueue.addAll(newQueue);
      _queueHash = newHash; // Cache the new hash

      // Force update mediaItem to ensure UI gets the new track metadata in real-time
      final index = _player.currentIndex;
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
  
  List<int> get effectiveIndices => _player.effectiveIndices ?? [];

  // --- Audio Parameters ---

  Future<void> setVolume(double volume) => _player.setVolume(volume);

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

    await _playlist.move(fromIndex, toIndex);

    _currentQueue.clear();
    _currentQueue.addAll(updatedQueue);
    _queueHash = _generateQueueHash(updatedQueue);
  }
}
