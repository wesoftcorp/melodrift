import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_notifier.dart';
import '../../data/services/share_service_impl.dart';
import 'player_dialogs.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Volume, Share & Speed Row
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
                onPressed: () => PlayerDialogs.showVolumeSlider(context, playerState, notifier),
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
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              iconSize: 36,
              onPressed: notifier.previous,
            ),
            GestureDetector(
              onTap: notifier.togglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: playerState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 40,
                        color: Colors.black,
                      ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              iconSize: 36,
              onPressed: notifier.next,
            ),
            IconButton(
              icon: Icon(
                playerState.isRepeat ? Icons.repeat_one : Icons.repeat,
                color: playerState.isRepeat ? theme.colorScheme.primary : Colors.white54,
              ),
              iconSize: 28,
              onPressed: notifier.toggleRepeat,
            ),
          ],
        ),
      ],
    );
  }
}
