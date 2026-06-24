import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/player_notifier.dart';
import '../../data/repositories/playlist_repository_impl.dart';
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
    final playerState = ref.watch(playerStateProvider);
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
                  playerState.volume == 0.0 ? Icons.volume_mute : Icons.volume_up,
                  color: Colors.white70,
                ),
                onPressed: () => PlayerDialogs.showVolumeSlider(context),
              ),
              if (playerState.currentSong != null)
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70),
                  onPressed: () {
                    final song = playerState.currentSong!;
                    ref.read(shareServiceProvider).shareSong(
                          title: song.title,
                          artist: song.artist,
                          youtubeId: song.videoId,
                        );
                  },
                ),
              TextButton.icon(
                icon: const Icon(Icons.speed, color: Colors.white70, size: 18),
                label: Text(
                  '${playerState.speed}x',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
                onPressed: () => PlayerDialogs.showSpeedSelection(context, playerState, notifier),
              ),
              TextButton.icon(
                icon: Icon(
                  playerState.sleepTimeRemaining != null ? Icons.snooze : Icons.access_time,
                  color: playerState.sleepTimeRemaining != null ? theme.colorScheme.primary : Colors.white70,
                  size: 18,
                ),
                label: Text(
                  playerState.sleepTimeRemaining != null
                      ? _formatTimerDuration(playerState.sleepTimeRemaining!)
                      : 'Timer',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: playerState.sleepTimeRemaining != null ? theme.colorScheme.primary : Colors.white70,
                  ),
                ),
                onPressed: () => PlayerDialogs.showSleepTimerDialog(context, playerState, notifier),
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
                color: playerState.isShuffle ? theme.colorScheme.primary : Colors.white54,
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
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (playerState.isLoading)
                      const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black26),
                        ),
                      ),
                    Icon(
                      playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 46,
                      color: Colors.black,
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
                playerState.repeatMode == AudioServiceRepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: playerState.repeatMode != AudioServiceRepeatMode.none
                    ? theme.colorScheme.primary
                    : Colors.white54,
              ),
              iconSize: 28,
              onPressed: notifier.toggleRepeat,
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white54),
              iconSize: 28,
              tooltip: 'Add to playlist',
              onPressed: playerState.currentSong == null
                  ? null
                  : () => _showAddToPlaylistDialog(
                        context,
                        playerState.currentSong!,
                      ),
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

  String _formatTimerDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
