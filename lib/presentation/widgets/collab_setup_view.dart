import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/collaboration_notifier.dart';

class CollabSetupView extends ConsumerStatefulWidget {
  final CollaborationState state;

  const CollabSetupView({
    required this.state,
    super.key,
  });

  @override
  ConsumerState<CollabSetupView> createState() => _CollabSetupViewState();
}

class _CollabSetupViewState extends ConsumerState<CollabSetupView> {
  final TextEditingController _roomController = TextEditingController();

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.people_outline, size: 80, color: Colors.grey),
        const SizedBox(height: 24),
        Text(
          'Listen Together',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a room to host your friends or enter a room code to join and listen in perfect sync.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () => ref.read(collaborationProvider.notifier).createRoom(),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Host a Room'),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _roomController,
          decoration: const InputDecoration(
            hintText: 'Enter 6-digit room code',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            final code = _roomController.text.trim();
            if (code.length == 6) {
              ref.read(collaborationProvider.notifier).joinRoom(code);
            }
          },
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Join Room'),
        ),
        if (widget.state.error != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.state.error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ]
      ],
    );
  }
}
