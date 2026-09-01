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

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
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
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(playerStateProvider.notifier).playQueue(tracks);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text(
                              'Play All',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                            final shuffled = List<Song>.from(tracks)..shuffle();
                            ref.read(playerStateProvider.notifier).playQueue(shuffled);
                            Navigator.pop(context);
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
      final album = await repo.getAlbumDetails(id, fallbackTitle: title);
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
    final Map<String, List<Color>> gradients = {
      'relax': [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      'workout': [const Color(0xFFf12711), const Color(0xFFf5af19)],
      'energize': [const Color(0xFFFF007F), const Color(0xFF7F00FF)],
      'party': [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
      'commute': [const Color(0xFF00c6ff), const Color(0xFF0072ff)],
      'romance': [const Color(0xFFfc4a1a), const Color(0xFFf7b733)],
      'sad': [const Color(0xFF232526), const Color(0xFF414345)],
      'focus': [const Color(0xFF3A6073), const Color(0xFF16213e)],
      'feel good': [const Color(0xFF56ab2f), const Color(0xFFa8e063)],
      'sleep': [const Color(0xFF0f2027), const Color(0xFF203a43)],
      'chill': [const Color(0xFF005C97), const Color(0xFF363795)],
      'happy': [const Color(0xFFe96c1e), const Color(0xFFFFCE54)],
      'pop': [const Color(0xFFFF007F), const Color(0xFFff6ec7)],
      'hip-hop': [const Color(0xFF1a1a2e), const Color(0xFF6c3483)],
      'rock': [const Color(0xFF833ab4), const Color(0xFFfd1d1d)],
      'jazz': [const Color(0xFF134E5E), const Color(0xFF71B280)],
      'classical': [const Color(0xFF614385), const Color(0xFF516395)],
      'edm': [const Color(0xFF00c6ff), const Color(0xFF7F00FF)],
      'lo-fi': [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
      'k-pop': [const Color(0xFFf953c6), const Color(0xFFb91d73)],
      'bollywood': [const Color(0xFFe96c1e), const Color(0xFFFFCE54)],
      'devotional': [const Color(0xFFf7971e), const Color(0xFFffd200)],
      '90s hits': [const Color(0xFF56ab2f), const Color(0xFFa8e063)],
      'retro': [const Color(0xFFfc4a1a), const Color(0xFFf7b733)],
      'gaming': [const Color(0xFF11998e), const Color(0xFF00c6ff)],
    };
    return gradients[title.toLowerCase()] ?? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];
  }

  IconData _getMoodIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('workout')) return Icons.fitness_center;
    if (t.contains('focus')) return Icons.psychology;
    if (t.contains('relax')) return Icons.spa;
    if (t.contains('party')) return Icons.celebration;
    if (t.contains('romance')) return Icons.favorite;
    if (t.contains('sad') || t.contains('melancholy')) return Icons.sentiment_very_dissatisfied;
    if (t.contains('chill') || t.contains('sleep')) return Icons.nights_stay;
    if (t.contains('happy')) return Icons.sentiment_very_satisfied;
    if (t.contains('pop')) return Icons.star;
    if (t.contains('hip')) return Icons.headphones;
    if (t.contains('rock')) return Icons.electric_bolt;
    if (t.contains('jazz')) return Icons.piano;
    if (t.contains('classical')) return Icons.library_music;
    if (t.contains('edm')) return Icons.graphic_eq;
    if (t.contains('lo-fi') || t.contains('lofi')) return Icons.nights_stay;
    if (t.contains('k-pop') || t.contains('kpop')) return Icons.auto_awesome;
    if (t.contains('bollywood')) return Icons.movie;
    if (t.contains('devotional')) return Icons.temple_hindu;
    if (t.contains('90s')) return Icons.replay;
    if (t.contains('retro')) return Icons.radio;
    if (t.contains('gaming')) return Icons.sports_esports;
    return Icons.music_note;
  }
}
