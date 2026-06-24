import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_notifier.dart';

class PlayerDialogs {
  static void showVolumeSlider(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(playerStateProvider);
            final notifier = ref.read(playerStateProvider.notifier);
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
                  Slider(
                    value: state.volume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      notifier.setVolume(val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static void showSpeedSelection(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
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

  static void showSleepTimerDialog(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.sleepTimeRemaining != null) ...[
                Text(
                  'Remaining: ${_formatDuration(state.sleepTimeRemaining!)}',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Turn Off Timer', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    notifier.setSleepTimer(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(color: Colors.white12),
              ],
              ...[5, 15, 30, 45, 60].map((minutes) {
                return ListTile(
                  title: Text('$minutes Minutes', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    notifier.setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
