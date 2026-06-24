import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/playlist.dart';
import '../screens/details_screen.dart';

class PlaylistsList extends ConsumerWidget {
  const PlaylistsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlistRepo = ref.watch(playlistRepositoryProvider);

    return FutureBuilder<List<Playlist>>(
      future: playlistRepo.getPlaylists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final playlists = snapshot.data ?? [];
        if (playlists.isEmpty) {
          return const Center(child: Text('Create playlists to start organizing'));
        }
        return ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: playlist.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: playlist.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.playlist_play),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.playlist_play),
                      ),
              ),
              title: Text(playlist.title),
              subtitle: Text('${playlist.trackCount} songs'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'view') {
                    unawaited(Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => DetailsScreen(
                          id: playlist.id,
                          title: playlist.title,
                          artworkUrl: playlist.artworkUrl,
                          type: 'playlist',
                        ),
                      ),
                    ));
                  } else if (value == 'delete') {
                    // Show confirmation dialog
                    unawaited(showDialog<void>(
                      context: context,
                      builder: (alertContext) => AlertDialog(
                        title: const Text('Delete Playlist'),
                        content: Text('Are you sure you want to delete "${playlist.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertContext),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await playlistRepo.deletePlaylist(playlist.id);
                              if (context.mounted) Navigator.pop(alertContext);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ));
                  } else if (value == 'downloadAll') {
                    _downloadPlaylist(context, ref, playlist);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_full, size: 20),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'downloadAll',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Download All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => DetailsScreen(
                      id: playlist.id,
                      title: playlist.title,
                      artworkUrl: playlist.artworkUrl,
                      type: 'playlist',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _downloadPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
    final downloadRepo = ref.read(downloadRepositoryProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Download Playlist'),
        content: Text(
          'Download all ${playlist.songs.length} songs from "${playlist.title}"?\n\n'
          'This may take a while depending on your connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

               // Show progress dialog
               if (context.mounted) {
                   await showDialog<void>(
                     context: context,
                     barrierDismissible: false,
                     builder: (progressContext) => StatefulBuilder(
                      builder: (context, setState) {
                        int downloaded = 0;
                        final total = playlist.songs.length;

                      // Download in background
                      Future.microtask(() async {
                        for (final song in playlist.songs) {
                          try {
                            await downloadRepo.downloadSong(song);
                            downloaded++;
                            setState(() {});
                          } catch (e) {
                            // Continue downloading other songs
                          }
                        }
                        if (progressContext.mounted) {
                          Navigator.pop(progressContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloaded $downloaded/$total songs'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      });

                      return AlertDialog(
                        title: const Text('Downloading'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(value: downloaded / total),
                            const SizedBox(height: 16),
                            Text('$downloaded / $total songs'),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
