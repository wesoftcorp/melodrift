import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../core/theme/tokens.dart';

class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({super.key});

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  @override
  Widget build(BuildContext context) {
    // Fine-grained: controls only rebuild when playback state or controls change,
    // NOT on every position/progress tick.
    final (:isPlaying, :isLoading) = ref.watch(playbackStateProvider);
    final controls = ref.watch(playbackControlsProvider);
    final currentSong = ref.watch(currentSongProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    return Column(

      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Playback Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: controls.isShuffle ? AppColors.onSurface : AppColors.onSurfaceVariant,
                ),
                iconSize: 24,
                onPressed: notifier.toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: AppColors.onSurface),
                iconSize: 32,
                onPressed: notifier.previous,
              ),
              // Play/Pause Morphing Button — 72 px
              GestureDetector(
                onTap: notifier.togglePlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle, // In a real app with custom shapes, this could be a polygon when playing
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                          ),
                        ),
                      Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                        color: AppColors.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: AppColors.onSurface),
                iconSize: 32,
                onPressed: notifier.next,
              ),
              IconButton(
                icon: Icon(
                  controls.repeatMode == AudioServiceRepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  color: controls.repeatMode != AudioServiceRepeatMode.none
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
                iconSize: 24,
                onPressed: notifier.toggleRepeat,
              ),
              // Keep the more options menu for functionality
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant),
                iconSize: 24,
                enabled: currentSong != null,
                onSelected: (value) {
                  if (value == 'playlist' && currentSong != null) {
                    _showAddToPlaylistDialog(context, currentSong);
                  } else if (value == 'queue') {
                    _showSearchAndAddToQueueDialog(context);
                  } else if (value == 'download' && currentSong != null) {
                    ref.read(downloadRepositoryProvider).downloadSong(currentSong);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading ${currentSong.title}...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add, size: 20),
                        SizedBox(width: 12),
                        Text('Add to playlist'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'queue',
                    child: Row(
                      children: [
                        Icon(Icons.queue_music, size: 20),
                        SizedBox(width: 12),
                        Text('Add to queue'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 12),
                        Text('Download'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    final playlistRepo = ref.read(playlistRepositoryProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => FutureBuilder(
        future: playlistRepo.getPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              title: Text('Add to Playlist'),
              content: SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
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
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
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

  void _showSearchAndAddToQueueDialog(BuildContext context) {
    final musicRepo = ref.read(musicRepositoryProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final searchController = TextEditingController();
    List<Song> searchResults = [];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Song to Queue'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search song, artist, or album...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.isEmpty) {
                      setDialogState(() => searchResults = []);
                      return;
                    }
                    try {
                      final results = await musicRepo.searchSongs(query);
                      if (mounted) {
                        setDialogState(() => searchResults = results);
                      }
                    } catch (e) {
                      // Search error - just ignore
                    }
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: searchResults.isEmpty
                      ? Center(
                          child: Text(
                            searchController.text.isEmpty
                                ? 'Start typing to search...'
                                : 'No songs found',
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final song = searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.music_note),
                              title: Text(song.title),
                              subtitle: Text(song.artist),
                              onTap: () async {
                                await notifier.addToQueue(song);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added "${song.title}" to queue'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                searchController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
