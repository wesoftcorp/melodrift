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

class SearchResultsView extends ConsumerWidget {
  final String query;

  const SearchResultsView({
    required this.query,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(musicRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
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

  Widget _buildSongsTab(MusicRepository repo) {
    return FutureBuilder<List<Song>>(
      future: repo.searchSongs(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final songs = snapshot.data ?? [];
        if (songs.isEmpty) return const Center(child: Text('No songs found'));
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
      future: repo.searchAlbums(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final albums = snapshot.data ?? [];
        if (albums.isEmpty) return const Center(child: Text('No albums found'));
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
      future: repo.searchArtists(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final artists = snapshot.data ?? [];
        if (artists.isEmpty) return const Center(child: Text('No artists found'));
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 180),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: artist.artworkUrl.isNotEmpty
                    ? CachedNetworkImageProvider(artist.artworkUrl)
                    : null,
                child: artist.artworkUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(artist.name),
              trailing: artist.isVerified ? const Icon(Icons.verified, color: Colors.blue) : null,
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

