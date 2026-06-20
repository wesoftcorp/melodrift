import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_notifier.dart';

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
        // Volume & Speed Slider Row
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
                onPressed: () => _showVolumeSlider(context, playerState, notifier),
              ),
              TextButton.icon(
                icon: const Icon(Icons.speed, color: Colors.white70, size: 18),
                label: Text(
                  '${playerState.speed}x',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
                onPressed: () => _showSpeedSelection(context, playerState, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Main Control Buttons
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
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

  void _showVolumeSlider(BuildContext context, PlayerState state, PlayerNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Adjust Volume', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Slider(
                    value: state.volume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      notifier.setVolume(val);
                      setModalState(() {});
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSelection(BuildContext context, PlayerState state, PlayerNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        title: const Text('Playback Speed', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
              value: speed,
              groupValue: state.speed,
              activeColor: Colors.white,
              onChanged: (val) {
                if (val != null) notifier.setSpeed(val);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
