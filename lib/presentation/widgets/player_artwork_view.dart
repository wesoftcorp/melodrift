import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/apple_music_service.dart';
import 'premium_player_components.dart';

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
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (theme.colorScheme.primary).withAlpha(isPlaying ? 70 : 0),
                  blurRadius: isPlaying ? 40 : 0,
                  spreadRadius: isPlaying ? 2 : 0,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AppleMotionArtworkPlayer(
                title: song.title,
                artist: song.artist,
                staticArtworkUrl: song.artworkUrl,
                isPlaying: isPlaying,
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),
        // ── Song Info ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32), // player-padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700, // headline-lg
                        fontSize: 28, // headline-lg-mobile
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis, // Or Marquee if added later
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // ── Seek Bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SquigglySeeker(
                progress: progress,
                isPlaying: isPlaying,
                onChangeEnd: (val) {
                  final targetMs = (val * duration.inMilliseconds).toInt();
                  ref.read(playerStateProvider.notifier).seek(
                        Duration(milliseconds: targetMs),
                      );
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatDuration(duration, isNegative: false),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
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


class AppleMotionArtworkPlayer extends StatefulWidget {
  final String title;
  final String artist;
  final String staticArtworkUrl;
  final bool isPlaying;

  const AppleMotionArtworkPlayer({
    required this.title,
    required this.artist,
    required this.staticArtworkUrl,
    required this.isPlaying,
    super.key,
  });

  @override
  State<AppleMotionArtworkPlayer> createState() => _AppleMotionArtworkPlayerState();
}

class _AppleMotionArtworkPlayerState extends State<AppleMotionArtworkPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMotionArtwork();
  }

  @override
  void didUpdateWidget(AppleMotionArtworkPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.artist != widget.artist) {
      _loadMotionArtwork();
    } else if (_isInitialized && _controller != null) {
      if (widget.isPlaying && !_controller!.value.isPlaying) {
        _controller!.play();
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _loadMotionArtwork() async {
    // Dispose old controller
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final url = await getIt<AppleMusicService>().getMotionArtworkUrl(widget.title, widget.artist);
      if (url != null && url.isNotEmpty && mounted) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0.0); // Muted for artwork

        if (mounted) {
          setState(() {
            _controller = controller;
            _isInitialized = true;
            _isLoading = false;
          });
          if (widget.isPlaying) {
            await controller.play();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staticImage = CachedNetworkImage(
      imageUrl: widget.staticArtworkUrl,
      width: 280,
      height: 280,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.music_note, size: 100, color: theme.colorScheme.onSurface),
      ),
    );

    if (_isLoading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          staticImage,
          Center(
            child: CircularProgressIndicator(color: theme.colorScheme.onSurface),
          ),
        ],
      );
    }

    if (_isInitialized && _controller != null) {
      return SizedBox(
        width: 280,
        height: 280,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    return staticImage;
  }
}
