import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/album.dart';
import '../../domain/repositories/music_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../providers/player_notifier.dart';
import '../widgets/song_card.dart';
import '../widgets/album_card.dart';

@RoutePage()
class DetailsScreen extends ConsumerWidget {
  final String id;
  final String title;
  final String artworkUrl;
  final String type; // 'album', 'playlist', 'artist', 'mood', 'songList', 'albumList'
  final List<Song>? preloadedSongs;
  final List<Album>? preloadedAlbums;

  const DetailsScreen({
    required this.id,
    required this.title,
    required this.type,
    this.artworkUrl = '',
    this.preloadedSongs,
    this.preloadedAlbums,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(musicRepositoryProvider);


    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: type == 'songList'
          ? _buildSongList(context, ref, preloadedSongs ?? [])
          : type == 'albumList'
              ? _buildAlbumGrid(context, preloadedAlbums ?? [])
              : FutureBuilder<Map<String, dynamic>>(
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
                                return SongCard(song: song);
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

  Widget _buildSongList(BuildContext context, WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text('No songs available'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongCard(song: song);
      },
    );
  }

  Widget _buildAlbumGrid(BuildContext context, List<Album> albums) {
    if (albums.isEmpty) {
      return const Center(child: Text('No albums available'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(album: album, size: 140);
      },
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
    final isMood = type == 'mood';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
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
                    decoration: isMood
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
                      isMood ? _getMoodIcon(title) : Icons.music_note,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
          if (detailsText.isNotEmpty)
            Text(
              detailsText,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  List<Color> _getMoodGradientColors(String title) {
    final Map<String, List<Color>> gradients = {
      'relax': [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      'workout': [const Color(0xFFf12711), const Color(0xFFf5af19)],
      'energize': [const Color(0xFFFF007F), const Color(0xFF7F00FF)],
      'party': [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
      'commute': [const Color(0xFF00c6ff), const Color(0xFF0072ff)],
      'romance': [const Color(0xFFfc4a1a), const Color(0xFFf7b733)],
      'sad': [const Color(0xFF232526), const Color(0xFF414345)],
      'focus': [const Color(0xFF3A6073), const Color(0xFF3A6073)],
      'feel good': [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      'sleep': [const Color(0xFF0f2027), const Color(0xFF203a43)],
    };
    return gradients[title.toLowerCase()] ?? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];
  }

  IconData _getMoodIcon(String title) {
    switch (title.toLowerCase()) {
      case 'relax':
        return Icons.spa_outlined;
      case 'workout':
        return Icons.fitness_center_outlined;
      case 'energize':
        return Icons.bolt_outlined;
      case 'party':
        return Icons.celebration_outlined;
      case 'commute':
        return Icons.directions_bus_outlined;
      case 'romance':
        return Icons.favorite_outline;
      case 'sad':
        return Icons.sentiment_very_dissatisfied_outlined;
      case 'focus':
        return Icons.self_improvement_outlined;
      case 'feel good':
        return Icons.emoji_emotions_outlined;
      case 'sleep':
        return Icons.bedtime_outlined;
      default:
        return Icons.music_note_outlined;
    }
  }
}
