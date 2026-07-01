import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../core/theme/tokens.dart';

import 'premium_player_components.dart';

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
              // Morphing Play Button — 72 px
              MorphingPlayButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                onTap: notifier.togglePlay,
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
            ],
          ),
        ),
      ],
    );
  }

}

