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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSourceFilterChip('All', 'All'),
                const SizedBox(width: 8),
                _buildSourceFilterChip('YouTube Music', '🔴 YouTube'),
                const SizedBox(width: 8),
                _buildSourceFilterChip('JioSaavn', '🟢 JioSaavn'),
              ],
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
      future: repo.searchSongs(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        var songs = snapshot.data ?? [];
        
        if (_selectedSourceFilter == 'YouTube Music') {
          songs = songs.where((s) => s.source.toLowerCase().contains('youtube')).toList();
        } else if (_selectedSourceFilter == 'JioSaavn') {
          songs = songs.where((s) => s.source.toLowerCase().contains('jiosaavn')).toList();
        }

        if (songs.isEmpty) return const Center(child: Text('No songs found for selected filter'));
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 180),
          itemCount: songs.length,
          itemBuilder: (context, index) => SongCard(song: songs[index]),
        );
      },
    );
  }


  Widget _buildAlbumsTab(MusicRepository repo) {
    return FutureBuilder<List<Album>>(
      future: repo.searchAlbums(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        var albums = snapshot.data ?? [];
        if (_selectedSourceFilter == 'YouTube Music') {
          albums = albums.where((a) => a.source.toLowerCase().contains('youtube')).toList();
        } else if (_selectedSourceFilter == 'JioSaavn') {
          albums = albums.where((a) => a.source.toLowerCase().contains('jiosaavn')).toList();
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
      future: repo.searchArtists(widget.query),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final rawArtists = snapshot.data ?? [];
        final artists = rawArtists.where((artist) {
          final name = artist.name.trim().toLowerCase();
          final url = artist.artworkUrl.trim();
          if (name.contains('muhammad atif aslam') && (url.isEmpty || url.contains('default') || url.contains('avatar') || url.contains('jiosaavn'))) {
            return false;
          }
          return url.isNotEmpty && !url.contains('blank');
        }).toList();


        if (artists.isEmpty) return const Center(child: Text('No artists found'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 180),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(artist.artworkUrl),
              ),
              title: Text(artist.name),
              subtitle: const Text('Artist'),
              trailing: artist.isVerified ? const Icon(Icons.verified, color: Colors.blue, size: 18) : null,

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
            );
          },
        );
      },
    );
  }
}

