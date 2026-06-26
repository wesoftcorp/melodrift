import 'dart:io';
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Info'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _showSongDetailsDialog(context, song),
                  ),
                  PopupMenuButton<String>(
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

  void _showSongDetailsDialog(BuildContext context, Song song) {
    final localSource = ref.read(localMusicSourceProvider);

    showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<List<Object?>>(
        future: Future.wait([
          localSource.getDownloadRecord(song.id),
          _getFileSize(song.streamUrl),
        ]),
        builder: (context, snapshot) {
          final record = snapshot.data?[0];
          final fileSize = snapshot.data?[1] as int?;

          return AlertDialog(
            title: const Text('Song Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Title', song.title),
                  _detailRow('Artist', song.artist),
                  _detailRow('Album', song.album.isEmpty ? 'Unknown' : song.album),
                  _detailRow('Duration', song.duration.toString().split('.').first),
                  _detailRow('Downloaded Size', _formatSize(fileSize)),
                  _detailRow('Download Quality', record != null ? ((record as dynamic).quality ?? 'Unknown').toString() : 'Unknown'),
                  _detailRow('Video ID', song.videoId),
                  _detailRow('Local Path', song.streamUrl ?? 'Unavailable'),
                  _detailRow('Artwork URL', song.artworkUrl.isEmpty ? 'Unavailable' : song.artworkUrl),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<int?> _getFileSize(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.length();
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return 'Unavailable';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
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
