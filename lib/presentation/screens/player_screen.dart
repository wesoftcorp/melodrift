import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../providers/player_notifier.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_artwork_view.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/theme_provider.dart';
import '../providers/player_providers.dart';
import '../widgets/song_options_sheet.dart';

final relatedSongsProvider = FutureProvider.family<List<Song>, String>((ref, videoId) async {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.getRelatedSongs(videoId);
});

@RoutePage()
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  late final DraggableScrollableController _sheetController;
  late final TabController _sheetTabController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    final initialTab = ref.read(playerSelectedTabProvider);
    _sheetTabController = TabController(
      length: 2,
      initialIndex: initialTab,
      vsync: this,
    );
    _sheetTabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_sheetTabController.indexIsChanging || _sheetTabController.index != ref.read(playerSelectedTabProvider)) {
      ref.read(playerSelectedTabProvider.notifier).state = _sheetTabController.index;
    }
  }

  @override
  void dispose() {
    _sheetTabController.removeListener(_onTabChanged);
    _sheetController.dispose();
    _sheetTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch only the song/metadata — NOT position, to avoid full-screen rebuilds every ~100ms
    final song = ref.watch(currentSongProvider);

    if (song == null) {
      return const Scaffold(body: Center(child: Text('No song playing')));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? AppColors.darkBackground : theme.colorScheme.background;
    final radial1Color = isDark ? const Color(0x33141E32) : theme.colorScheme.primary.withOpacity(0.08);
    final radial2Color = isDark ? const Color(0x2232143C) : theme.colorScheme.secondary.withOpacity(0.06);
    final centerGradColor = isDark ? const Color(0xCC0A0F1E) : theme.colorScheme.surface.withOpacity(0.85);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // 1. Mesh Background Simulation — wrapped in RepaintBoundary so it
          //    is never repainted during playback position updates.
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.6, -0.4),
                          radius: 1.5,
                          colors: [radial1Color, Colors.transparent],
                          stops: const [0.0, 0.5],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.6, 0.4),
                          radius: 1.5,
                          colors: [radial2Color, Colors.transparent],
                          stops: const [0.0, 0.5],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, 0),
                          radius: 1.0,
                          colors: [centerGradColor, scaffoldBg],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main content UI (Artwork & Controls)
          const SafeArea(
            child: Column(
              children: [
                SizedBox(height: 56),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 16),
                        PlayerArtworkView(),
                        SizedBox(height: 24),
                        PlayerControls(),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Padding space for the collapsed sheet handle
                SizedBox(height: 80),
              ],
            ),
          ),

          // 3. Sliding tab panel (LYRICS & QUEUE) — Anchored cleanly to bottom
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, rootConstraints) {
                final screenH = rootConstraints.maxHeight > 0
                    ? rootConstraints.maxHeight
                    : MediaQuery.of(context).size.height;
                final bottomPadding = MediaQuery.of(context).padding.bottom;
                // Min height dynamically sized for handle + safe area with zero overflow
                final minSize = ((64.0 + bottomPadding) / (screenH > 0 ? screenH : 800)).clamp(0.07, 0.16);

                return DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: minSize,
                  minChildSize: minSize,
                  maxChildSize: 0.88,
                  snap: true,
                  snapSizes: [minSize, 0.88],
                  builder: (context, sheetScrollController) {
                    return RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh.withAlpha(245),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(140),
                              blurRadius: 30,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: SafeArea(
                              top: false,
                              bottom: true,
                              child: LayoutBuilder(
                                builder: (context, sheetConstraints) {
                                  final isExpanded = sheetConstraints.maxHeight > 130;

                                  return Column(
                                    children: [
                                      // ── Drag handle & title ──────────────────────
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () async {
                                          if (_sheetController.isAttached) {
                                            final isExp = _sheetController.size > 0.45;
                                            await _sheetController.animateTo(
                                              isExp ? minSize : 0.88,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOutCubic,
                                            );
                                          }
                                        },
                                        // Vertical drag on handle directly drives the sheet
                                        onVerticalDragUpdate: (details) {
                                          if (_sheetController.isAttached) {
                                            final delta = details.primaryDelta ?? 0;
                                            final newSize = _sheetController.size - (delta / screenH);
                                            _sheetController.jumpTo(newSize.clamp(minSize, 0.88));
                                          }
                                        },
                                        onVerticalDragEnd: (details) {
                                          if (_sheetController.isAttached) {
                                            final velocity = details.primaryVelocity ?? 0;
                                            double target;
                                            if (velocity > 400) {
                                              target = minSize; // fast swipe down → collapse
                                            } else if (velocity < -400) {
                                              target = 0.88; // fast swipe up → expand
                                            } else {
                                              // snap to nearest anchor
                                              target = _sheetController.size > 0.45 ? 0.88 : minSize;
                                            }
                                            _sheetController.animateTo(
                                              target,
                                              duration: const Duration(milliseconds: 280),
                                              curve: Curves.easeOutCubic,
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Pill handle
                                              Container(
                                                width: 42,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(2.5),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Lyrics & Queue',
                                                    style: AppTextStyles.titleSmall.copyWith(
                                                      color: theme.colorScheme.onSurface,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  ListenableBuilder(
                                                    listenable: _sheetController,
                                                    builder: (context, _) {
                                                      final isExp = _sheetController.isAttached && _sheetController.size > 0.45;
                                                      return Icon(
                                                        isExp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                        size: 24,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ── TabBar & Content (rendered only when expanded) ──
                                      if (isExpanded) ...[
                                        GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onVerticalDragUpdate: (details) {
                                            if (_sheetController.isAttached) {
                                              final delta = details.primaryDelta ?? 0;
                                              final newSize = _sheetController.size - (delta / screenH);
                                              _sheetController.jumpTo(newSize.clamp(minSize, 0.88));
                                            }
                                          },
                                          onVerticalDragEnd: (details) {
                                            if (_sheetController.isAttached) {
                                              final velocity = details.primaryVelocity ?? 0;
                                              double target;
                                              if (velocity > 400) {
                                                target = minSize;
                                              } else if (velocity < -400) {
                                                target = 0.88;
                                              } else {
                                                target = _sheetController.size > 0.45 ? 0.88 : minSize;
                                              }
                                              _sheetController.animateTo(
                                                target,
                                                duration: const Duration(milliseconds: 280),
                                                curve: Curves.easeOutCubic,
                                              );
                                            }
                                          },
                                          child: TabBar(
                                            controller: _sheetTabController,
                                            onTap: (index) {
                                              ref.read(playerSelectedTabProvider.notifier).state = index;
                                            },
                                            labelColor: theme.colorScheme.primary,
                                            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                                            indicatorColor: theme.colorScheme.primary,
                                            indicatorSize: TabBarIndicatorSize.tab,
                                            dividerColor: Colors.transparent,
                                            labelStyle: AppTextStyles.monoSectionHeader,
                                            tabs: const [
                                              Tab(text: 'QUEUE'),
                                              Tab(text: 'LYRICS'),
                                            ],
                                          ),
                                        ),

                                        // ── Tab Content View (Expanded to fill bottom 100%) ──
                                        Expanded(
                                          child: TabBarView(
                                            controller: _sheetTabController,
                                            physics: const NeverScrollableScrollPhysics(),
                                            children: [
                                              _buildQueueTab(sheetScrollController),
                                              Consumer(
                                                builder: (ctx, cRef, _) {
                                                  final position = cRef.watch(currentPositionProvider);
                                                  return LyricsView(
                                                    song: song,
                                                    position: position,
                                                    scrollController: sheetScrollController,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 4. Top App Bar (ALWAYS ON TOP)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildTopAppBar(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Fine-grained: only rebuild when sleepTimer or currentSong changes,
    // NOT on every position tick
    final hasActiveTimer = ref.watch(
      playerStateProvider.select((s) => s.sleepTimeRemaining != null),
    );
    final hasSong = ref.watch(
      playerStateProvider.select((s) => s.currentSong != null),
    );
    final currentSong = hasSong
        ? ref.watch(playerStateProvider.select((s) => s.currentSong))
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 28,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: 'Minimize Player',
            onPressed: () => context.router.maybePop(),
          ),
          Text(
            'NOW PLAYING',
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 2.0,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  hasActiveTimer ? Icons.timer : Icons.timer_outlined,
                  color: hasActiveTimer ? Colors.amberAccent : theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Sleep Timer',
                onPressed: () => _showSleepTimerDialog(context, ref),
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: isDark ? 'Light Theme' : 'Dark Theme',
                onPressed: () {
                  ref.read(themeProvider.notifier).setThemeMode(
                      isDark ? AppThemeMode.light : AppThemeMode.dark);
                },
              ),
              if (hasSong && currentSong != null)
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Song Options',
                  onPressed: () => showSongOptionsMenu(
                    context,
                    ref,
                    currentSong,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Use .read here since this is a one-shot dialog open, not a reactive watch
    final sleepRemaining = ref.read(playerStateProvider).sleepTimeRemaining;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bedtime_rounded, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Sleep Timer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (sleepRemaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${sleepRemaining.inMinutes} min remaining',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTimerChip(ctx, ref, '15 Min', const Duration(minutes: 15)),
                    _buildTimerChip(ctx, ref, '30 Min', const Duration(minutes: 30)),
                    _buildTimerChip(ctx, ref, '45 Min', const Duration(minutes: 45)),
                    _buildTimerChip(ctx, ref, '60 Min', const Duration(minutes: 60)),
                  ],
                ),
                const SizedBox(height: 16),
                if (sleepRemaining != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(playerStateProvider.notifier).cancelSleepTimer();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sleep timer cancelled')),
                      );
                    },
                    icon: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
                    label: const Text('Cancel Active Timer', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerChip(BuildContext context, WidgetRef ref, String label, Duration duration) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: const Icon(Icons.timer_outlined, size: 18),
      label: Text(label),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      onPressed: () {
        ref.read(playerStateProvider.notifier).setSleepTimer(duration);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep timer set for ${duration.inMinutes} minutes')),
        );
      },
    );
  }

  Widget _buildQueueTab(ScrollController? scrollController) {
    return Consumer(
      builder: (context, ref, child) {
        final displayedQueue = ref.watch(playerStateProvider.select((s) => s.playbackQueue));
        final currentSongId = ref.watch(playerStateProvider.select((s) => s.currentSong?.id));
        final isShuffle = ref.watch(playerStateProvider.select((s) => s.isShuffle));

        if (displayedQueue.isEmpty) {
          final theme = Theme.of(context);
          return Center(child: Text('Queue is empty', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))));
        }

        if (isShuffle) {
          return ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayedQueue.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, index) => _buildQueueTile(
              context,
              ref,
              displayedQueue[index],
              index,
              currentSongId,
            ),
          );
        } else {
          return ReorderableListView.builder(
            scrollController: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayedQueue.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, index) => _buildQueueTile(
              context,
              ref,
              displayedQueue[index],
              index,
              currentSongId,
            ),
            onReorder: (oldIndex, newIndex) {
              ref.read(playerStateProvider.notifier).reorderQueue(oldIndex, newIndex);
            },
          );
        }
      },
    );
  }

  Widget _buildQueueTile(
    BuildContext context,
    WidgetRef ref,
    Song song,
    int index,
    String? currentSongId,
  ) {
    final theme = Theme.of(context);
    final isCurrent = currentSongId == song.id;

    return ListTile(
      key: ValueKey('${song.id}_$index'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: song.artworkUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 44,
            height: 44,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.music_note, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.38),
        ),
      ),
      trailing: isCurrent
          ? Icon(Icons.volume_up, color: theme.colorScheme.primary)
          : IconButton(
              icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 20),
              tooltip: 'Remove from queue',
              onPressed: () {
                ref.read(playerStateProvider.notifier).removeFromQueue(song);
              },
            ),
      onTap: () {
        final originalQueue = ref.read(playerStateProvider).queue;
        final originalIndex = originalQueue.indexWhere((s) => s.id == song.id);
        if (originalIndex != -1) {
          ref.read(playerStateProvider.notifier).skipToQueueItem(originalIndex);
        }
      },
    );
  }
}
