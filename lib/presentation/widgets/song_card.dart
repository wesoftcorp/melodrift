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
    // select: only rebuilds when currentSong id or isPlaying changes, not on every position tick
    final (:currentId, :isPlaying) = ref.watch(
      playerStateProvider.select((s) => (currentId: s.currentSong?.id, isPlaying: s.isPlaying)),
    );
    final isCurrent = currentId == song.id;
    final isCurrentlyPlaying = isCurrent && isPlaying;

    return InkWell(
      onTap: () {
        if (isCurrent) {
          ref.read(playerStateProvider.notifier).togglePlay();
        } else {
          ref.read(playerStateProvider.notifier).playSong(song);
        }
      },
      splashColor: theme.colorScheme.primary.withAlpha(50),
      highlightColor: theme.colorScheme.primary.withAlpha(25),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: isCurrent ? BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withAlpha(150),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(20),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ) : null,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getSourceColor(song.source).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getSourceColor(song.source).withOpacity(0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getSourceEmoji(song.source),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getSourceColor(song.source),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          song.artist,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SongDownloadButton(song: song),
            IconButton(
              icon: isCurrentlyPlaying 
                  ? Icon(Icons.equalizer, color: theme.colorScheme.primary)
                  : Icon(Icons.play_arrow_outlined, color: isCurrent ? theme.colorScheme.primary : null),
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

  String _getSourceEmoji(String source) {
    return '🩵'; // same heart symbol for all, color differentiates
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'SoundCloud':
        return const Color(0xFFAA00FF); // SoundCloud purple
      case 'JioSaavn':
        return Colors.tealAccent;
      default:
        return Colors.redAccent; // YouTube Music red
    }
  }
}
