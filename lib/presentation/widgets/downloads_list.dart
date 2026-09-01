import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_music_source.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';
import 'song_card.dart';

class DownloadsList extends ConsumerStatefulWidget {
  const DownloadsList({super.key});

  @override
  ConsumerState<DownloadsList> createState() => _DownloadsListState();
}

class _DownloadsListState extends ConsumerState<DownloadsList> {
  @override
  Widget build(BuildContext context) {
    final localSource = ref.watch(localMusicSourceProvider);
    final theme = Theme.of(context);

    return FutureBuilder<List<Song>>(
      future: localSource.getDownloadedSongs().then((list) => list
          .map((ls) => Song(
                id: ls.songId,
                title: ls.title,
                artist: ls.artist,
                album: ls.album,
                duration: Duration(milliseconds: ls.durationMs),
                artworkUrl: ls.artworkUrl,
                videoId: ls.videoId,
                streamUrl: ls.filePath,
                source: 'Offline',
              ))
          .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snapshot.data ?? [];
        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_done_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No downloaded songs yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download songs to listen offline anytime',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Action Buttons: Play All & Shuffle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(playerStateProvider.notifier).playQueue(songs);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        'Play All (${songs.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5F1F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final shuffled = List<Song>.from(songs)..shuffle();
                      ref.read(playerStateProvider.notifier).playQueue(shuffled);
                    },
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    label: const Text('Shuffle'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Downloaded Song Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongCard(
                    song: song,
                    queue: songs,
                    queueIndex: index,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
