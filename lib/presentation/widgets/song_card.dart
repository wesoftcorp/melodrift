import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';
import 'song_download_button.dart';

class SongCard extends ConsumerWidget {
  final Song song;
  final double size;

  const SongCard({
    required this.song,
    this.size = 56.0,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playerState = ref.watch(playerStateProvider);
    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;

    return InkWell(
      onTap: () {
        if (isCurrent) {
          ref.read(playerStateProvider.notifier).togglePlay();
        } else {
          ref.read(playerStateProvider.notifier).playSong(song);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song.artworkUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isCurrent ? theme.colorScheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SongDownloadButton(song: song),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow_outlined),
              color: isCurrent ? theme.colorScheme.primary : null,
              onPressed: () {
                if (isCurrent) {
                  ref.read(playerStateProvider.notifier).togglePlay();
                } else {
                  ref.read(playerStateProvider.notifier).playSong(song);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
