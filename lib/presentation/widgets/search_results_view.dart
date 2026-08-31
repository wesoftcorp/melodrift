import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import 'song_card.dart';
import 'album_card.dart';
import '../screens/details_screen.dart';

class SearchResultsView extends ConsumerStatefulWidget {
  final String query;

  const SearchResultsView({
    required this.query,
    super.key,
  });

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

/// Keyed wrapper so when query changes the widget fully rebuilds, clearing
/// stale Future results from the previous search.
class SearchResultsViewKeyed extends StatelessWidget {
  final String query;
  const SearchResultsViewKeyed({required this.query, super.key});

  @override
  Widget build(BuildContext context) =>
      SearchResultsView(key: ValueKey(query), query: query);
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  String _selectedSourceFilter = 'All'; // 'All', 'YouTube Music', 'JioSaavn'

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(musicRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSourceFilterChip('All', 'All'),
                  const SizedBox(width: 8),
                  _buildSourceFilterChip('JioSaavn', '⚡ HD Tracks'),
                  const SizedBox(width: 8),
                  _buildSourceFilterChip('Spotify', '✨ Global Hits'),
                  const SizedBox(width: 8),
                  _buildSourceFilterChip('SoundCloud', '🎧 Lo-Fi & Mixes'),
                ],
              ),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Songs'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSongsTab(repo),
                _buildAlbumsTab(repo),
                _buildArtistsTab(repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFilterChip(String filterKey, String label) {
    final isSelected = _selectedSourceFilter == filterKey;
    final theme = Theme.of(context);
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selectedColor: const Color(0xFFFF5F1F),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      onSelected: (selected) {
        setState(() {
          _selectedSourceFilter = filterKey;
        });
      },
    );
  }

  Widget _buildSongsTab(MusicRepository repo) {
    return FutureBuilder<List<Song>>(
      // key the future on query + filter so switching the filter chip re-fires
      key: ValueKey('${widget.query}_$_selectedSourceFilter'),
      future: repo.searchSongs(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
            ),
          );
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        var songs = snapshot.data ?? [];

        if (_selectedSourceFilter == 'JioSaavn') {
          songs = songs.where((s) =>
              s.source.toLowerCase().contains('jiosaavn') ||
              s.source.toLowerCase().contains('saavn') ||
              s.id.startsWith('jiosaavn_')).toList();
        } else if (_selectedSourceFilter == 'SoundCloud') {
          songs = songs.where((s) =>
              s.source.toLowerCase().contains('soundcloud') ||
              s.id.startsWith('sc_')).toList();
        } else if (_selectedSourceFilter == 'Spotify') {
          songs = songs.where((s) =>
              s.source.toLowerCase().contains('spotify') ||
              s.id.startsWith('spotify_')).toList();
        }

        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _selectedSourceFilter == 'All'
                      ? 'No songs found for "${widget.query}"'
                      : 'No results for this filter. Try "All".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 180),
          itemCount: songs.length,
          itemBuilder: (context, index) => SongCard(
            song: songs[index],
            queue: songs,
            queueIndex: index,
          ),
        );
      },
    );
  }


  Widget _buildAlbumsTab(MusicRepository repo) {
    return FutureBuilder<List<Album>>(
      key: ValueKey('albums_${widget.query}_$_selectedSourceFilter'),
      future: repo.searchAlbums(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
            ),
          );
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        var albums = snapshot.data ?? [];
        if (_selectedSourceFilter == 'JioSaavn') {
          albums = albums.where((a) => a.source.toLowerCase().contains('jiosaavn')).toList();
        } else if (_selectedSourceFilter == 'SoundCloud') {
          albums = albums.where((a) => a.source.toLowerCase().contains('soundcloud')).toList();
        } else if (_selectedSourceFilter == 'Spotify') {
          albums = albums.where((a) => a.source.toLowerCase().contains('spotify')).toList();
        }



        if (albums.isEmpty) return const Center(child: Text('No albums found for selected filter'));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumCard(album: album);
          },
        );
      },
    );
  }

  Widget _buildArtistsTab(MusicRepository repo) {
    return FutureBuilder<List<Artist>>(
      // Artists tab: source filter doesn't apply (Artist has no source field),
      // so always use 'All' for the future key to avoid wiping results.
      key: ValueKey('artists_${widget.query}'),
      future: repo.searchArtists(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
            ),
          );
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final artists = snapshot.data ?? [];

        if (artists.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_search_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No artists found for "${widget.query}"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 180),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            final theme = Theme.of(context);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5F1F).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: artist.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artist.artworkUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFF5F1F)),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFF5F1F)),
                              ),
                            ),
                          ),
                  ),
                ),
                title: Text(
                  artist.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  artist.subscribers ?? 'Verified Artist',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => DetailsScreen(
                        id: artist.id,
                        title: artist.name,
                        artworkUrl: artist.artworkUrl,
                        type: 'artist',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

}

