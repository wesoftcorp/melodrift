import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../core/theme/tokens.dart';

/// Artwork card with breathing scale animation when playing.
class PlayerArtworkView extends ConsumerStatefulWidget {
  const PlayerArtworkView({super.key});

  @override
  ConsumerState<PlayerArtworkView> createState() => _PlayerArtworkViewState();
}

class _PlayerArtworkViewState extends ConsumerState<PlayerArtworkView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _breathAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _syncAnimation(bool isPlaying) {
    if (isPlaying && !_breathController.isAnimating) {
      _breathController.repeat(reverse: true);
    } else if (!isPlaying && _breathController.isAnimating) {
      _breathController.stop();
      _breathController.animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Metadata: only rebuilds when song or isPlaying changes
    final song = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(playbackStateProvider).isPlaying;
    final theme = Theme.of(context);

    if (song == null) return const SizedBox.shrink();

    _syncAnimation(isPlaying);

    // Progress values: rebuild only within seek bar — use fine-grained providers
    final progress = ref.watch(progressRatioProvider);
    final position = ref.watch(currentPositionProvider);
    final duration = ref.watch(currentDurationProvider);
    final remaining = duration > position ? duration - position : Duration.zero;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Artwork with breathing animation ───────────────────────────────
        AnimatedBuilder(
          animation: _breathAnim,
          builder: (context, child) => Transform.scale(
            scale: _breathAnim.value,
            child: child,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(isPlaying ? 80 : 0),
                  blurRadius: isPlaying ? 30 : 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: song.artworkUrl,
                width: 280,
                height: 280,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 280,
                  height: 280,
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 100, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),
        // ── Song Info ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                song.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // ── Seek Bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.outlineVariant,
                  thumbColor: theme.colorScheme.primary,
                  overlayColor: theme.colorScheme.primary.withAlpha(50),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (val) {
                    final targetMs = (val * duration.inMilliseconds).toInt();
                    ref.read(playerStateProvider.notifier).seek(
                          Duration(milliseconds: targetMs),
                        );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: AppTextStyles.monoCaption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      _formatDuration(remaining, isNegative: remaining.inSeconds > 0),
                      style: AppTextStyles.monoCaption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d, {bool isNegative = false}) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final prefix = isNegative ? '-' : '';
    return '$prefix$m:${s.toString().padLeft(2, '0')}';
  }
}
