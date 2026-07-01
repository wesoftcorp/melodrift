import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/lyrics.dart';
import '../../data/repositories/lyrics_repository_impl.dart';
import '../providers/player_notifier.dart';
import '../providers/translation_notifier.dart';

final lyricsProvider = FutureProvider.family<List<LyricLine>, Song>((ref, song) async {
  final repository = ref.watch(lyricsRepositoryProvider);
  return repository.getLyrics(song.id, song.title, song.artist, song.duration);
});

class LyricsView extends ConsumerStatefulWidget {
  final Song song;
  final Duration position;
  final ScrollController? scrollController;

  const LyricsView({
    required this.song,
    required this.position,
    this.scrollController,
    super.key,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  late final ScrollController _scrollController;
  int _lastActiveIndex = -1;
  // Cache: last computed active index and the lines list it was computed for
  int _cachedActiveIndex = -1;
  List<LyricLine>? _cachedLines;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollToActive(int index) {
    if (index == _lastActiveIndex || !mounted) return;
    if (!_scrollController.hasClients) return;
    _lastActiveIndex = index;
    const itemHeight = 70.0;
    final offset = (index * itemHeight) - 100.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// O(n) scan but only runs when position crosses a line boundary.
  int _computeActiveIndex(List<LyricLine> lines, Duration position) {
    // Fast path: same lines list, check if current cached index is still valid
    if (_cachedLines == lines && _cachedActiveIndex >= 0) {
      final posMs = position.inMilliseconds;
      final current = _cachedActiveIndex;
      // Still valid if position is within the same line's range
      final nextStart = (current + 1 < lines.length) ? lines[current + 1].timeMs : null;
      if (posMs >= lines[current].timeMs && (nextStart == null || posMs < nextStart)) {
        return current;
      }
    }
    // Full scan only when line boundary is crossed
    _cachedLines = lines;
    int idx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (position.inMilliseconds >= lines[i].timeMs) {
        idx = i;
      } else {
        break;
      }
    }
    _cachedActiveIndex = idx;
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyricsAsync = ref.watch(lyricsProvider(widget.song));
    final transState = ref.watch(translationProvider);

    return lyricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, __) => const Center(child: Text('Lyrics not available', style: TextStyle(color: Colors.white70))),
        data: (lines) {
        if (lines.isEmpty) {
          return const Center(child: Text('No lyrics found', style: TextStyle(color: Colors.white70)));
        }

        final activeIndex = _computeActiveIndex(lines, widget.position);
        if (activeIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive(activeIndex));
        }

        return Stack(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.15, 0.85, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: lines.length,
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),

                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isActive = index == activeIndex;
                  final translation = transState.translatedLines[line.timeMs];

                  return GestureDetector(
                    onTap: () => ref.read(playerStateProvider.notifier).seek(Duration(milliseconds: line.timeMs)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            line.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              fontSize: isActive ? 21 : 17,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (transState.isTranslating) ...[
                            const SizedBox(height: 6),
                            Text(
                              translation ?? (transState.isModelDownloading ? '...' : ''),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isActive ? Colors.amberAccent : Colors.white.withValues(alpha: 0.25),
                                fontSize: isActive ? 16 : 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.language, color: Colors.white70),
                    onSelected: (lang) => ref.read(translationProvider.notifier).setTargetLanguage(lang, lines),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'es', child: Text('Spanish')),
                      const PopupMenuItem(value: 'fr', child: Text('French')),
                      const PopupMenuItem(value: 'de', child: Text('German')),
                      const PopupMenuItem(value: 'ja', child: Text('Japanese')),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      transState.isTranslating ? Icons.g_translate : Icons.translate,
                      color: transState.isTranslating ? Colors.amberAccent : Colors.white70,
                    ),
                    onPressed: () {
                      ref.read(translationProvider.notifier).toggleTranslation(!transState.isTranslating, lines);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
