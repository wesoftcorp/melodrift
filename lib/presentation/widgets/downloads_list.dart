import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/datasources/local_music_source.dart';
import '../../data/repositories/download_repository_impl.dart';
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
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(downloadRepositoryProvider).deleteDownload(song.id);
                  setState(() {});
                },
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
}
