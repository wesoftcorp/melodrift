import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/song.dart';
import 'player_notifier.dart';

/// High-frequency update providers (position, buffered position)
/// These are separated from other state to prevent unnecessary rebuilds
/// of widgets that don't care about playback progress.

/// Current playback position (updates ~10/sec after throttling)
/// Use this for progress bars, time displays
final currentPositionProvider = Provider<Duration>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return playerState.position;
});

/// Current buffered position
/// Use this for buffered progress visualization
final bufferedPositionProvider = Provider<Duration>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return playerState.bufferedPosition;
});

/// Current song duration
/// Use this for total time displays
final currentDurationProvider = Provider<Duration>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return playerState.duration;
});

/// Currently playing song metadata
/// Use this for artwork, title, artist displays
final currentSongProvider = Provider<Song?>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return playerState.currentSong;
});

/// Playback state (playing, loading)
/// Use this for play/pause button, loading indicator
final playbackStateProvider = Provider<({bool isPlaying, bool isLoading})>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return (isPlaying: playerState.isPlaying, isLoading: playerState.isLoading);
});

/// Queue of songs
/// Use this for "up next" list, queue display
final queueProvider = Provider<List<Song>>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return playerState.queue;
});

/// Playback controls state (volume, speed, shuffle, repeat)
/// Use this for control panel
final playbackControlsProvider = Provider<({
  double volume,
  double speed,
  bool isShuffle,
  AudioServiceRepeatMode repeatMode,
})>((ref) {
  final playerState = ref.watch(playerStateProvider);
  return (
    volume: playerState.volume,
    speed: playerState.speed,
    isShuffle: playerState.isShuffle,
    repeatMode: playerState.repeatMode,
  );
});

/// Progress ratio (0.0 to 1.0) for progress bar
/// Computed from position and duration
final progressRatioProvider = Provider<double>((ref) {
  final position = ref.watch(currentPositionProvider);
  final duration = ref.watch(currentDurationProvider);
  
  if (duration.inMilliseconds == 0) return 0.0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
});

/// Time remaining string
/// Computed from position and duration
final timeRemainingProvider = Provider<String>((ref) {
  final position = ref.watch(currentPositionProvider);
  final duration = ref.watch(currentDurationProvider);
  
  final remaining = duration - position;
  final minutes = remaining.inMinutes;
  final seconds = remaining.inSeconds % 60;
  
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
});

/// Check if there's a next song in queue
final hasNextSongProvider = Provider<bool>((ref) {
  final playerState = ref.watch(playerStateProvider);
  final currentSong = playerState.currentSong;
  
  if (currentSong == null || playerState.queue.isEmpty) return false;
  
  final currentIndex = playerState.queue.indexWhere((s) => s.id == currentSong.id);
  return currentIndex != -1 && currentIndex + 1 < playerState.queue.length;
});

/// Check if there's a previous song in queue
final hasPreviousSongProvider = Provider<bool>((ref) {
  final playerState = ref.watch(playerStateProvider);
  final currentSong = playerState.currentSong;
  
  if (currentSong == null || playerState.queue.isEmpty) return false;
  
  final currentIndex = playerState.queue.indexWhere((s) => s.id == currentSong.id);
  return currentIndex > 0;
});

/// Next song in queue (if available)
final nextSongProvider = Provider<Song?>((ref) {
  final playerState = ref.watch(playerStateProvider);
  final currentSong = playerState.currentSong;
  
  if (currentSong == null || playerState.queue.isEmpty) return null;
  
  final currentIndex = playerState.queue.indexWhere((s) => s.id == currentSong.id);
  if (currentIndex == -1 || currentIndex + 1 >= playerState.queue.length) return null;
  
  return playerState.queue[currentIndex + 1];
});
