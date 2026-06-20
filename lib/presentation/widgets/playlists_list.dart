import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/entities/playlist.dart';
import 'item_details_sheet.dart';

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
              onTap: () {
                ItemDetailsSheet.show(
                  context,
                  id: playlist.id,
                  title: playlist.title,
                  artworkUrl: playlist.artworkUrl,
                  type: 'playlist',
                );
              },
            );
          },
        );
      },
    );
  }
}
