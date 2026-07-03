import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/router/app_router.gr.dart';
import '../../providers/player_notifier.dart';
import '../../providers/player_providers.dart';

/// Mini-player extracted into its own widget so only it rebuilds on position ticks.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Metadata: only rebuilds when song/playing/loading changes
    final song = ref.watch(currentSongProvider);
    final (:isPlaying, :isLoading) = ref.watch(playbackStateProvider);
    // Progress: rebuilds on every position tick — scoped only to this widget
    final progress = ref.watch(progressRatioProvider);

    if (song == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // Capsule content
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                  child: Row(
                    children: [
                      // Artwork
                      GestureDetector(
                        onTap: () => context.router.push(const PlayerRoute()),
                        child: Hero(
                          tag: 'player_artwork',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: song.artworkUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.artworkUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.music_note),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text metadata
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.router.push(const PlayerRoute()),
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0.0;
                            if (velocity < -300) {
                              ref.read(playerStateProvider.notifier).next();
                            } else if (velocity > 300) {
                              ref.read(playerStateProvider.notifier).previous();
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Skip previous button
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).previous();
                        },
                      ),
                      // Play/Pause button
                      IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                                ),
                              ),
                            Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 24,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).togglePlay();
                        },
                      ),
                      // Skip next button
                      IconButton(
                        icon: Icon(
                          Icons.skip_next_rounded,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).next();
                        },
                      ),
                    ],
                  ),
                ),
                // Compact seek line at the very bottom edge of the capsule
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 2.5,
                      backgroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
