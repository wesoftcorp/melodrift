import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioHandlerProvider = Provider<MelodriftAudioHandler>((ref) {
  throw UnimplementedError('MelodriftAudioHandler is not initialized yet. Override audioHandlerProvider in ProviderScope.');
});

class MelodriftAudioHandler extends BaseAudioHandler with QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  late final ConcatenatingAudioSource _playlist;

  MelodriftAudioHandler() {
    _init();
  }

  void _init() {
    _playlist = ConcatenatingAudioSource(children: []);
    
    // Set the initial audio source
    _player.setAudioSource(_playlist).catchError((_) => null);

    // 1. Forward playback events to the system media session
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // 2. Listen to index changes to update mediaItem
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    // 3. Handle processing states automatically
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
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
      queueIndex: event.currentIndex,
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
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

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

  Future<void> _syncPlaylist(List<MediaItem> newQueue) async {
    if (newQueue.isEmpty) {
      await _playlist.clear();
      return;
    }

    final newSources = newQueue.map((item) {
      final streamUrl = item.extras?['streamUrl'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        if (streamUrl.startsWith('/') || streamUrl.contains(':\\') || streamUrl.contains(':/')) {
          return AudioSource.file(streamUrl);
        } else {
          return AudioSource.uri(Uri.parse(streamUrl));
        }
      }
      return AudioSource.uri(Uri.parse(''));
    }).toList();

    final currentLength = _playlist.length;
    bool isAppend = currentLength > 0 && currentLength <= newQueue.length;
    if (isAppend) {
      for (int i = 0; i < currentLength; i++) {
        if (queue.value[i].id != newQueue[i].id) {
          isAppend = false;
          break;
        }
      }
    }

    if (isAppend) {
      final toAdd = newSources.sublist(currentLength);
      await _playlist.addAll(toAdd);
    } else {
      await _playlist.clear();
      await _playlist.addAll(newSources);
    }
  }

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
}
