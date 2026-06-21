import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../providers/collaboration_notifier.dart';
import '../widgets/collab_setup_view.dart';
import '../widgets/collab_room_view.dart';

@RoutePage()
class ListenTogetherScreen extends ConsumerWidget {
  const ListenTogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collabState = ref.watch(collaborationProvider);
    final room = collabState.room;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen Together', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: collabState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: room == null
                  ? CollabSetupView(state: collabState)
                  : CollabRoomView(room: room, state: collabState),
            ),
    );
  }
}
