import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/lyrics.dart';
import '../../data/repositories/lyrics_repository_impl.dart';
import '../providers/player_notifier.dart';

final lyricsProvider = FutureProvider.family<List<LyricLine>, Song>((ref, song) async {
  final repository = ref.watch(lyricsRepositoryProvider);
  return repository.getLyrics(song.id, song.title, song.artist, song.duration);
});

class LyricsView extends ConsumerStatefulWidget {
  final Song song;
  final Duration position;

  const LyricsView({
    required this.song,
    required this.position,
    super.key,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int index, int totalLines) {
    if (index == _lastActiveIndex || !mounted) return;
    _lastActiveIndex = index;

    const itemHeight = 60.0; // Estimate height per line
    final offset = (index * itemHeight) - 100.0;
    
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyricsAsync = ref.watch(lyricsProvider(widget.song));

    return lyricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, _) => Center(
        child: Text(
          'Lyrics not available',
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
      ),
      data: (lines) {
        if (lines.isEmpty) {
          return Center(
            child: Text(
              'No lyrics found for this song',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          );
        }

        // Find active line index
        int activeIndex = -1;
        for (int i = 0; i < lines.length; i++) {
          if (widget.position.inMilliseconds >= lines[i].timeMs) {
            activeIndex = i;
          } else {
            break;
          }
        }

        // Scroll to active index
        if (activeIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActive(activeIndex, lines.length);
          });
        }

        return ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.15, 0.85, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: lines.length,
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            itemBuilder: (context, index) {
              final line = lines[index];
              final isActive = index == activeIndex;

              return GestureDetector(
                onTap: () {
                  ref.read(playerStateProvider.notifier).seek(
                        Duration(milliseconds: line.timeMs),
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    line.text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: isActive ? 22 : 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
