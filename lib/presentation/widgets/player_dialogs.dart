import 'package:flutter/material.dart';
import '../providers/player_notifier.dart';

class PlayerDialogs {
  static void showVolumeSlider(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
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
}
