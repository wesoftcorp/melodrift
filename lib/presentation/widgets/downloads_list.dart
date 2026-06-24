import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/datasources/local_music_source.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';

class DownloadsList extends ConsumerStatefulWidget {
  const DownloadsList({super.key});

  @override
  ConsumerState<DownloadsList> createState() => _DownloadsListState();
}

class _DownloadsListState extends ConsumerState<DownloadsList> {
  @override
  Widget build(BuildContext context) {
    final localSource = ref.watch(localMusicSourceProvider);

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
              ))
          .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snapshot.data ?? [];
        if (songs.isEmpty) {
          return const Center(child: Text('No downloaded songs yet'));
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: song.artworkUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                   errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                ),
              ),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    await ref.read(downloadRepositoryProvider).deleteDownload(song.id);
                    setState(() {});
                  } else if (value == 'addToPlaylist') {
                    _showAddToPlaylistDialog(context, ref, song);
                  } else if (value == 'share') {
                    // Share functionality can be added here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                   const PopupMenuItem(
                    value: 'addToPlaylist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add, size: 20),
                        SizedBox(width: 8),
                        Text('Add to Playlist'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 8),
                        Text('Share'),
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
                ref.read(playerStateProvider.notifier).playQueue(songs, initialIndex: index);
              },
            );
          },
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
    final playlistRepo = ref.read(playlistRepositoryProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => FutureBuilder(
        future: playlistRepo.getPlaylists(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const AlertDialog(
               title: Text('Add to Playlist'),
               content: CircularProgressIndicator(),
             );
           }

          final playlists = snapshot.data ?? [];

          return AlertDialog(
            title: const Text('Add to Playlist'),
            content: playlists.isEmpty
                ? const Text('No playlists found. Create one first.')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return ListTile(
                          title: Text(playlist.title),
                          subtitle: Text('${playlist.trackCount} songs'),
                          onTap: () async {
                            await playlistRepo.addSongToPlaylist(playlist.id, song);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to ${playlist.title}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}
