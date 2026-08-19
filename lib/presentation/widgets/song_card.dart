import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../providers/player_notifier.dart';
import 'song_download_button.dart';


class SongCard extends ConsumerWidget {
  final Song song;
  final double size;
  final List<Song>? queue;
  final int? queueIndex;

  const SongCard({
    required this.song,
    this.size = 56.0,
    this.queue,
    this.queueIndex,
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

    void onPlay() {
      final notifier = ref.read(playerStateProvider.notifier);
      if (isCurrent && isPlaying) {
        notifier.togglePlay();
      } else if (queue != null && queueIndex != null) {
        notifier.playQueue(queue!, initialIndex: queueIndex!);
      } else {
        notifier.playSong(song);
      }
    }

    return InkWell(
      onTap: onPlay,
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
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _getSongSourceColor(song.source),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getSongSourceColor(song.source).withOpacity(0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),

                      ),
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
            IconButton(
              icon: isCurrentlyPlaying 
                  ? Icon(Icons.equalizer, color: theme.colorScheme.primary)
                  : Icon(Icons.play_arrow_outlined, color: isCurrent ? theme.colorScheme.primary : null),
              color: isCurrent ? theme.colorScheme.primary : null,
              onPressed: onPlay,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => showSongOptionsMenu(context, ref, song, onPlay: onPlay),
            ),
          ],
        ),
      ),
    );
  }
}

void showSongOptionsMenu(BuildContext context, WidgetRef ref, Song song, {VoidCallback? onPlay}) {
  final theme = Theme.of(context);
  final effectiveOnPlay = onPlay ?? () {
    ref.read(playerStateProvider.notifier).playSong(song);
  };

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: song.artworkUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _getSongSourceColor(song.source),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${song.artist} • ${song.source}',
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
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Option 1: Play Song
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play Song'),
                onTap: () {
                  Navigator.pop(ctx);
                  effectiveOnPlay();
                },
              ),

              // Option 2: Add to Playlist
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddToPlaylistDialog(context, ref, song);
                },
              ),

              // Option 3: Download Song
              ListTile(
                leading: SongDownloadButton(song: song),
                title: const Text('Download Song'),
              ),

              // Option 4: Song Info
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Song Info'),
                onTap: () {
                  Navigator.pop(ctx);
                  showSongInfoDialog(context, song);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
  final playlistRepo = ref.read(playlistRepositoryProvider);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Add to Playlist'),
        content: FutureBuilder<List<Playlist>>(
          future: playlistRepo.getPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final playlists = snapshot.data ?? [];
            if (playlists.isEmpty) {
              return const Text('No playlists found. Create one in the Library tab.');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  return ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(pl.title),
                    subtitle: Text('${pl.trackCount} tracks'),
                    onTap: () async {
                      await playlistRepo.addSongToPlaylist(pl.id, song);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${pl.title}')),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

void showSongInfoDialog(BuildContext context, Song song) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Song Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${song.title}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text('Artist: ${song.artist}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text('Album: ${song.album.isNotEmpty ? song.album : "Single"}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text('Source: ${song.source}', style: theme.textTheme.bodyMedium),
            if (song.duration > Duration.zero) ...[
              const SizedBox(height: 6),
              Text('Duration: ${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}', style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Color _getSongSourceColor(String source) {
  switch (source.toLowerCase()) {
    case 'jiosaavn':
      return const Color(0xFF00E676); // JioSaavn Green Dot
    case 'spotify':
      return const Color(0xFF1DB954);
    case 'soundcloud':
      return const Color(0xFF9B5DE5);
    default:
      return const Color(0xFFFF3333); // YouTube Music Red Dot
  }
}



