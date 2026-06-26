import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';
import '../providers/song_recognition_notifier.dart';

class RecognizedSongCard extends ConsumerWidget {
  final Song song;
  const RecognizedSongCard({required this.song, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: song.artworkUrl,
              width: 160,
              height: 160,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 160,
                height: 160,
                color: Colors.grey.shade800,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 160,
                height: 160,
                color: Colors.grey.shade800,
                child: const Icon(Icons.music_note, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            song.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(songRecognitionProvider.notifier).cancel(),
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(playerStateProvider.notifier).playSong(song);
                    ref.read(songRecognitionProvider.notifier).cancel();
                    context.router.popForced();
                  },
                  child: const Text('Play'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
