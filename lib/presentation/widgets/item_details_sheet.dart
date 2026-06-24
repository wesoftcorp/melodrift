import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../providers/player_notifier.dart';
import '../../data/repositories/music_repository_impl.dart';
import 'song_download_button.dart';

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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatDuration(song.duration)),
                            const SizedBox(width: 8),
                            SongDownloadButton(song: song, size: 20),
                          ],
                        ),
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
    } else if (type == 'mood') {
      final songs = await repo.searchSongs('$title music');
      return {
        'tracks': songs.take(30).toList(),
        'subtitle': 'Curated $title playlist',
        'details': '${songs.length} tracks found',
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
                    decoration: type == 'mood'
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getMoodGradientColors(title),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                    child: Icon(
                      type == 'mood' ? _getMoodIcon(title) : Icons.music_note,
                      size: 80,
                      color: Colors.white,
                    ),
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

  List<Color> _getMoodGradientColors(String title) {
    const gradients = [
      [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Indigo/Violet
      [Color(0xFFf12711), Color(0xFFf5af19)], // Sunset orange
      [Color(0xFF11998e), Color(0xFF38ef7d)], // Emerald
      [Color(0xFFFF007F), Color(0xFF7F00FF)], // Neon Pink/Purple
      [Color(0xFF00c6ff), Color(0xFF0072ff)], // Sky Blue
      [Color(0xFFfc4a1a), Color(0xFFf7b733)], // Sunrise
    ];
    final index = title.hashCode.abs() % gradients.length;
    return gradients[index];
  }

  IconData _getMoodIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('workout')) return Icons.fitness_center;
    if (t.contains('focus')) return Icons.psychology;
    if (t.contains('relax')) return Icons.spa;
    if (t.contains('party')) return Icons.celebration;
    if (t.contains('romance')) return Icons.favorite;
    if (t.contains('sad') || t.contains('melancholy')) return Icons.sentiment_very_dissatisfied;
    return Icons.music_note;
  }
}
