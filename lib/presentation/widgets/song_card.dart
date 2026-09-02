import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';
import 'song_options_sheet.dart';
export 'song_options_sheet.dart';

class SongCard extends ConsumerWidget {
  final Song song;
  final double size;
  final List<Song>? queue;
  final int? queueIndex;

  const SongCard({
    required this.song,
    this.size = 56.0,
    this.queue,
    this.queueIndex,
    super.key,
  });

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (:currentId, :isPlaying) = ref.watch(
      playerStateProvider.select((s) => (currentId: s.currentSong?.id, isPlaying: s.isPlaying)),
    );
    final isCurrent = currentId == song.id ||
        (currentId != null && (currentId.endsWith(song.id) || song.id.endsWith(currentId)));
    final isCurrentlyPlaying = isCurrent && isPlaying;

    void onPlay() {
      final notifier = ref.read(playerStateProvider.notifier);
      if (isCurrentlyPlaying) {
        notifier.pause();
      } else if (queue != null && queueIndex != null) {
        notifier.playQueue(queue!, initialIndex: queueIndex!);
      } else {
        notifier.playSong(song);
      }
    }

    final durationStr = _formatDuration(song.duration);

    return InkWell(
      onTap: onPlay,
      splashColor: theme.colorScheme.primary.withAlpha(50),
      highlightColor: theme.colorScheme.primary.withAlpha(25),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: isCurrent
            ? BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withAlpha(150),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(25),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            // ── Artwork with Ambient Glow & Play Overlay ──────────────
            Container(
              decoration: isCurrentlyPlaying
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: song.artworkUrl,
                      width: size,
                      height: size,
                      memCacheWidth: (size * 2).toInt(),
                      memCacheHeight: (size * 2).toInt(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: size,
                        height: size,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: size * 0.45,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Title & Artist ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isCurrent ? theme.colorScheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrent
                          ? theme.colorScheme.primary.withOpacity(0.85)
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Trailing: Live Equalizer, Duration & 3-Dot Menu ───────
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isCurrentlyPlaying)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MiniAnimatedEqualizer(color: theme.colorScheme.primary),
                  ),
                if (durationStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Text(
                      durationStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  iconSize: 20,
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => showSongOptionsMenu(context, ref, song, onPlay: onPlay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic 3-bar animated equalizer that moves smoothly while song is playing.
class _MiniAnimatedEqualizer extends StatefulWidget {
  final Color color;
  const _MiniAnimatedEqualizer({required this.color});

  @override
  State<_MiniAnimatedEqualizer> createState() => _MiniAnimatedEqualizerState();
}

class _MiniAnimatedEqualizerState extends State<_MiniAnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 16,
          height: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar((4 + 10 * ((t + 0.15) % 1.0)).clamp(3.0, 15.0)),
              _buildBar((5 + 10 * (1.0 - t)).clamp(3.0, 15.0)),
              _buildBar((4 + 11 * ((t + 0.7) % 1.0)).clamp(3.0, 15.0)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 3.2,
      height: height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
