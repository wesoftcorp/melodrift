import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/services/share_service_impl.dart';
import '../../domain/entities/song.dart';
import 'player_dialogs.dart';

class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({super.key});

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) {
    // Fine-grained: controls only rebuild when playback state or controls change,
    // NOT on every position/progress tick.
    final (:isPlaying, :isLoading) = ref.watch(playbackStateProvider);
    final controls = ref.watch(playbackControlsProvider);
    final currentSong = ref.watch(currentSongProvider);
    final sleepTimeRemaining = ref.watch(
      playerStateProvider.select((s) => s.sleepTimeRemaining),
    );
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Column(

      mainAxisSize: MainAxisSize.min,
      children: [
        // Volume, Share, Speed & Sleep Timer Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  controls.volume == 0.0 ? Icons.volume_mute : Icons.volume_up,
                  color: Colors.white70,
                ),
                onPressed: () => PlayerDialogs.showVolumeSlider(context),
              ),
              if (currentSong != null)
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70),
                  onPressed: () {
                    ref.read(shareServiceProvider).shareSong(
                          title: currentSong.title,
                          artist: currentSong.artist,
                          youtubeId: currentSong.videoId,
                        );
                  },
                ),
              TextButton.icon(
                icon: const Icon(Icons.speed, color: Colors.white70, size: 18),
                label: Text(
                  '${controls.speed}x',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
                onPressed: () => PlayerDialogs.showSpeedSelection(
                  context,
                  ref.read(playerStateProvider),
                  notifier,
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  sleepTimeRemaining != null ? Icons.snooze : Icons.access_time,
                  color: sleepTimeRemaining != null ? theme.colorScheme.primary : Colors.white70,
                  size: 18,
                ),
                label: Text(
                  sleepTimeRemaining != null
                      ? _formatTimerDuration(sleepTimeRemaining)
                      : 'Timer',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: sleepTimeRemaining != null ? theme.colorScheme.primary : Colors.white70,
                  ),
                ),
                onPressed: () => PlayerDialogs.showSleepTimerDialog(
                  context,
                  ref.read(playerStateProvider),
                  notifier,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Main Playback Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: controls.isShuffle ? theme.colorScheme.primary : Colors.white54,
              ),
              iconSize: 28,
              onPressed: notifier.toggleShuffle,
            ),
            // Like button
            GestureDetector(
              onTap: () => setState(() => _isLiked = !_isLiked),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(_isLiked),
                  color: _isLiked ? Colors.redAccent : Colors.white54,
                  size: 28,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              iconSize: 36,
              onPressed: notifier.previous,
            ),
            // Play/Pause FAB — 80 px
            IconButton(
              iconSize: 80,
              padding: EdgeInsets.zero,
              icon: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(50),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                    Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 46,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              onPressed: notifier.togglePlay,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              iconSize: 36,
              onPressed: notifier.next,
            ),
            IconButton(
              icon: Icon(
                controls.repeatMode == AudioServiceRepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: controls.repeatMode != AudioServiceRepeatMode.none
                    ? theme.colorScheme.primary
                    : Colors.white54,
              ),
              iconSize: 28,
              onPressed: notifier.toggleRepeat,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              iconSize: 28,
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

  String _formatTimerDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
