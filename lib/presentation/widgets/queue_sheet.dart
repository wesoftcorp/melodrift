import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Fine-grained: only rebuilds when queue list or current song changes
    final queue = ref.watch(queueProvider);
    final currentSong = ref.watch(currentSongProvider);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Playing Queue',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: queue.isEmpty
                ? const Center(child: Text('Queue is empty'))
                : ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      final isCurrent = currentSong?.id == song.id;

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: song.artworkUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? theme.colorScheme.primary.withOpacity(0.8) : null,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(Icons.volume_up, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          ref.read(playerStateProvider.notifier).playQueue(queue, initialIndex: index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
