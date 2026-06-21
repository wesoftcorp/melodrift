import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/listening_room.dart';
import '../providers/collaboration_notifier.dart';

class CollabRoomView extends ConsumerWidget {
  final ListeningRoom room;
  final CollaborationState state;

  const CollabRoomView({
    required this.room,
    required this.state,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSong = room.currentSong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text(
                  'ROOM CODE',
                  style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      room.roomId,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: room.roomId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Room code copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Now Playing in Room', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ListTile(
          tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.music_note),
          title: Text(activeSong != null ? activeSong.title : 'Waiting for host...'),
          subtitle: Text(activeSong != null ? activeSong.artist : 'Let the music drift'),
        ),
        const SizedBox(height: 24),
        Text('Participants (${room.participants.length})', style: theme.textTheme.titleSmall),
        Expanded(
          child: ListView.builder(
            itemCount: room.participants.length,
            itemBuilder: (context, index) {
              final participant = room.participants[index];
              final isHost = participant == room.hostId;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(participant == state.userId ? 'You ($participant)' : participant),
                trailing: isHost
                    ? Chip(
                        label: const Text('Host'),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      )
                    : null,
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () => ref.read(collaborationProvider.notifier).leaveRoom(),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Leave Room'),
        ),
      ],
    );
  }
}
