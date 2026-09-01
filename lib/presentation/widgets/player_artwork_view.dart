import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/song.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/apple_music_service.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import 'premium_player_components.dart';
import 'song_options_sheet.dart';

/// Derives a harmonic vibrant glow color for a track using pure Dart HSL.
Color _getDynamicGlowColor(Song song, ThemeData theme) {
  final hash = song.title.hashCode ^ song.artist.hashCode;
  final hue = (hash.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.72, 0.62).toColor();
}

/// Artwork card with breathing scale animation, swipe-to-skip, double-tap-to-seek,
/// dynamic ambient palette glow, and 1-tap heart like button.
class PlayerArtworkView extends ConsumerStatefulWidget {
  const PlayerArtworkView({super.key});

  @override
  ConsumerState<PlayerArtworkView> createState() => _PlayerArtworkViewState();
}

class _PlayerArtworkViewState extends ConsumerState<PlayerArtworkView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnim;

  // Double-tap seek HUD overlay state
  int _seekOverlaySeconds = 0; // -10 or +10
  bool _showSeekOverlay = false;

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

  void _handleDoubleTapSeek(TapDownDetails details, BuildContext context, Duration position, Duration duration) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double localX = details.localPosition.dx;
    final double width = box.size.width;
    final isRight = localX > width / 2;

    final notifier = ref.read(playerStateProvider.notifier);
    if (isRight) {
      final target = position + const Duration(seconds: 10);
      notifier.seek(target > duration ? duration : target);
      setState(() {
        _seekOverlaySeconds = 10;
        _showSeekOverlay = true;
      });
    } else {
      final target = position - const Duration(seconds: 10);
      notifier.seek(target < Duration.zero ? Duration.zero : target);
      setState(() {
        _seekOverlaySeconds = -10;
        _showSeekOverlay = true;
      });
    }

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _showSeekOverlay = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Metadata: only rebuilds when song or isPlaying changes
    final song = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(playbackStateProvider).isPlaying;
    final position = ref.watch(currentPositionProvider);
    final duration = ref.watch(currentDurationProvider);
    final theme = Theme.of(context);

    if (song == null) return const SizedBox.shrink();

    _syncAnimation(isPlaying);

    final glowColor = _getDynamicGlowColor(song, theme);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Artwork with Gesture Controls & Dynamic Palette Glow ────────────
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -250) {
              // Swipe Left -> Next Track
              HapticFeedback.selectionClick();
              ref.read(playerStateProvider.notifier).next();
            } else if (velocity > 250) {
              // Swipe Right -> Previous Track
              HapticFeedback.selectionClick();
              ref.read(playerStateProvider.notifier).previous();
            }
          },
          onDoubleTapDown: (details) => _handleDoubleTapSeek(details, context, position, duration),
          child: AnimatedBuilder(
            animation: _breathAnim,
            builder: (context, child) => Transform.scale(
              scale: _breathAnim.value,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Dynamic Ambient Glow Aura Behind Artwork
                if (isPlaying)
                  Transform.scale(
                    scale: 1.15,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.45),
                            blurRadius: 50,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. Main Artwork Container
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(isPlaying ? 0.35 : 0.0),
                        blurRadius: isPlaying ? 35 : 0,
                        spreadRadius: isPlaying ? 2 : 0,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AppleMotionArtworkPlayer(
                          title: song.title,
                          artist: song.artist,
                          staticArtworkUrl: song.artworkUrl,
                          isPlaying: isPlaying,
                        ),

                        // Double-tap seek HUD overlay
                        if (_showSeekOverlay)
                          AnimatedOpacity(
                            opacity: _showSeekOverlay ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _seekOverlaySeconds > 0
                                            ? Icons.fast_forward_rounded
                                            : Icons.fast_rewind_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_seekOverlaySeconds > 0 ? '+' : ''}$_seekOverlaySeconds sec',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
        // ── Song Info, 1-Tap Heart Button & Options ───────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 1-Tap Quick Heart / Like Button
              _HeartLikeButton(song: song),
              const SizedBox(width: 4),
              // 3-Dot More Options
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 26),
                tooltip: 'More Options',
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => showSongOptionsMenu(context, ref, song),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        // ── Seek Bar — isolated Consumer ──────────────────────────────────
        const _PlayerSeekBar(),
      ],
    );
  }
}

/// 1-Tap Animated Heart Button with bouncing micro-interaction.
class _HeartLikeButton extends ConsumerStatefulWidget {
  final Song song;
  const _HeartLikeButton({required this.song});

  @override
  ConsumerState<_HeartLikeButton> createState() => _HeartLikeButtonState();
}

class _HeartLikeButtonState extends ConsumerState<_HeartLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _checkLikedState();
  }

  @override
  void didUpdateWidget(_HeartLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _checkLikedState();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkLikedState() async {
    final playlistRepo = ref.read(playlistRepositoryProvider);
    final favPlaylist = await playlistRepo.getPlaylist('favorites');
    final isFav = favPlaylist?.songs.any((s) => s.id == widget.song.id) ?? false;
    if (mounted) {
      setState(() => _isLiked = isFav);
    }
  }

  Future<void> _toggleLike() async {
    await HapticFeedback.selectionClick();
    unawaited(_animController.forward(from: 0.0));

    final playlistRepo = ref.read(playlistRepositoryProvider);
    final nextState = !_isLiked;
    setState(() => _isLiked = nextState);

    if (nextState) {
      await playlistRepo.addSongToPlaylist('favorites', widget.song);
    } else {
      await playlistRepo.removeSongFromPlaylist('favorites', widget.song.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scaleAnim,
      child: IconButton(
        icon: Icon(
          _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: _isLiked ? const Color(0xFFFF2D55) : theme.colorScheme.onSurfaceVariant,
          size: 26,
        ),
        tooltip: _isLiked ? 'Liked' : 'Like Song',
        onPressed: _toggleLike,
      ),
    );
  }
}

/// Isolated seek bar widget — watches position/progress providers independently
class _PlayerSeekBar extends ConsumerWidget {
  const _PlayerSeekBar();

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressRatioProvider);
    final position = ref.watch(currentPositionProvider);
    final duration = ref.watch(currentDurationProvider);
    final isPlaying = ref.watch(playbackStateProvider).isPlaying;
    final theme = Theme.of(context);

    return Padding(
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
                _fmt(position),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _fmt(duration),
                style: AppTextStyles.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        unawaited(_controller!.play());
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        unawaited(_controller!.pause());
      }
    }
  }

  Future<void> _loadMotionArtwork() async {
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
        await controller.setVolume(0.0);

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
