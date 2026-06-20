import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../providers/player_notifier.dart';
import '../../data/repositories/music_repository_impl.dart';

class ItemDetailsSheet extends ConsumerWidget {
  final String id;
  final String title;
  final String artworkUrl;
  final String type; // 'album', 'playlist', 'artist'

  const ItemDetailsSheet({
    required this.id,
    required this.title,
    required this.artworkUrl,
    required this.type,
    super.key,
  });

  static void show(
    BuildContext context, {
    required String id,
    required String title,
    required String artworkUrl,
    required String type,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ItemDetailsSheet(
            id: id,
            title: title,
            artworkUrl: artworkUrl,
            type: type,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.watch(musicRepositoryProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(repo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};
          final tracks = data['tracks'] as List<Song>? ?? [];
          final subtitle = data['subtitle'] as String? ?? '';
          final detailsText = data['details'] as String? ?? '';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(context, subtitle, detailsText),
              ),
              if (tracks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(playerStateProvider.notifier).playQueue(tracks);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = tracks[index];
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
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(_formatDuration(song.duration)),
                        onTap: () {
                          ref.read(playerStateProvider.notifier).playQueue(tracks, initialIndex: index);
                          Navigator.pop(context);
                        },
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchData(MusicRepository repo) async {
    if (type == 'album') {
      final album = await repo.getAlbumDetails(id);
      return {
        'tracks': album.tracks,
        'subtitle': album.artist,
        'details': '${album.songCount} songs',
      };
    } else if (type == 'playlist') {
      final playlist = await repo.getPlaylistDetails(id);
      return {
        'tracks': playlist.songs,
        'subtitle': playlist.description,
        'details': '${playlist.trackCount} songs',
      };
    } else if (type == 'artist') {
      final artist = await repo.getArtistDetails(id);
      // Fetch some popular songs of this artist
      final songs = await repo.searchSongs(artist.name);
      return {
        'tracks': songs.take(15).toList(),
        'subtitle': artist.subscribers != null ? '${artist.subscribers} subscribers' : '',
        'details': artist.isVerified ? 'Verified Artist' : '',
      };
    }
    return {};
  }

  Widget _buildHeader(BuildContext context, String subtitle, String detailsText) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: artworkUrl,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 80),
                  )
                : Container(
                    width: 160,
                    height: 160,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note, size: 80),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (detailsText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detailsText,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
