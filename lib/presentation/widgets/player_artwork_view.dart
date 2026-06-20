import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_notifier.dart';

class PlayerArtworkView extends ConsumerWidget {
  const PlayerArtworkView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;
    final theme = Theme.of(context);

    if (song == null) return const SizedBox.shrink();

    final progress = playerState.duration.inMilliseconds > 0
        ? playerState.position.inMilliseconds / playerState.duration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Artwork
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: song.artworkUrl,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 280,
              height: 280,
              color: Colors.grey[800],
              child: const Icon(Icons.music_note, size: 100, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 36),
        // Song Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                song.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Seek Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (val) {
                    final targetMs = (val * playerState.duration.inMilliseconds).toInt();
                    ref.read(playerStateProvider.notifier).seek(
                          Duration(milliseconds: targetMs),
                        );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(playerState.position),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(playerState.duration),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
