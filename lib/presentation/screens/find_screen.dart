import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../providers/song_recognition_notifier.dart';
import '../widgets/search_wave_painter.dart';
import '../widgets/recognized_song_card.dart';

@RoutePage()
class FindScreen extends ConsumerStatefulWidget {
  const FindScreen({super.key});

  @override
  ConsumerState<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends ConsumerState<FindScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songRecognitionProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songRecognitionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identify Song', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(songRecognitionProvider.notifier).cancel();
            context.router.popForced();
          },
        ),
      ),
      body: Stack(
        children: [
          if (state.status == SongRecognitionStatus.listening)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: CustomPaint(
                painter: SearchWavePainter(state.amplitude),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: _buildStateView(state, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateView(SongRecognitionState state, ThemeData theme) {
    switch (state.status) {
      case SongRecognitionStatus.idle:
      case SongRecognitionStatus.listening:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.15 * (0.5 + state.amplitude));
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: Icon(Icons.mic, size: 64, color: theme.colorScheme.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            Text(
              'Listening to ambient music...',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your device close to the source',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
          ],
        );
      case SongRecognitionStatus.success:
        return RecognizedSongCard(song: state.recognizedSong!);
      case SongRecognitionStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              state.errorMessage ?? 'Error identifying song',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(songRecognitionProvider.notifier).startListening(),
              child: const Text('Retry'),
            ),
          ],
        );
    }
  }
}
