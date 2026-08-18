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

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;

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
          // 1. Mesh Background Simulation
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.4),
                  radius: 1.5,
                  colors: [
                    radial1Color,
                    Colors.transparent,
                  ],
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
                  colors: [
                    radial2Color,
                    Colors.transparent,
                  ],
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
                  colors: [
                    centerGradColor,
                    scaffoldBg,
                  ],
                ),
              ),
            ),
          ),

          // 2. Main content UI
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(context),
                const Expanded(
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
                // Padding space for the collapsed sheet handle (approx 85px)
                const SizedBox(height: 85),
              ],
            ),
          ),

          // 3. Sliding tab panel (LYRICS & QUEUE) — anchored to bottom of Stack
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.1, 0.85],
              builder: (context, sheetScrollController) {
                final theme = Theme.of(context);
                // IMPORTANT: sheetScrollController MUST be the controller of the
                // outermost scrollable (CustomScrollView). This is what drives
                // the sheet's drag behaviour.
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(128),
                        blurRadius: 40,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHigh.withAlpha(220),
                        child: ListenableBuilder(
                          listenable: _sheetController,
                          builder: (context, _) {
                            final isExpanded = _sheetController.isAttached
                                ? _sheetController.size > 0.5
                                : false;

                            return CustomScrollView(
                              controller: sheetScrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [

                                // ── Drag handle & title ──────────────────────
                                SliverToBoxAdapter(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async {
                                      if (_sheetController.isAttached) {
                                        if (isExpanded) {
                                          if (sheetScrollController.hasClients) {
                                            await sheetScrollController.animateTo(
                                              0.0,
                                              duration: const Duration(milliseconds: 150),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                          await _sheetController.animateTo(
                                            0.1,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        } else {
                                          await _sheetController.animateTo(
                                            0.85,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 24, right: 24),
                                      child: Column(
                                        children: [
                                          // Pill handle
                                          Container(
                                            width: 48,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Lyrics & Queue',
                                                style: AppTextStyles.titleSmall.copyWith(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                                ),
                                              ),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.keyboard_arrow_up,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                size: 28,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Tab content (only when expanded) ─────────
                                if (isExpanded)
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: (MediaQuery.of(context).size.height * 0.85) - 80,

                                      child: DefaultTabController(
                                        length: 2,
                                        child: Column(
                                          children: [
                                            TabBar(
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
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: TabBarView(
                                                children: [
                                                  _buildQueueTab(null),
                                                  LyricsView(
                                                    song: song,
                                                    position: playerState.position,
                                                    scrollController: null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),


                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playerState = ref.watch(playerStateProvider);
    final hasActiveTimer = playerState.sleepTimeRemaining != null;

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
                onPressed: () {
                  ref.read(themeProvider.notifier).setThemeMode(
                      isDark ? AppThemeMode.light : AppThemeMode.dark);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playerState = ref.watch(playerStateProvider);

    showModalBottomSheet(
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
                if (playerState.sleepTimeRemaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Active: ${playerState.sleepTimeRemaining!.inMinutes} min remaining',
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
                if (playerState.sleepTimeRemaining != null)
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
        final playerState = ref.watch(playerStateProvider);
        final displayedQueue = playerState.playbackQueue;
        final currentSong = playerState.currentSong;

        if (displayedQueue.isEmpty) {
          final theme = Theme.of(context);
          return Center(child: Text('Queue is empty', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))));
        }

        if (playerState.isShuffle) {
          return ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayedQueue.length,
            itemBuilder: (context, index) => _buildQueueTile(
              context,
              ref,
              displayedQueue[index],
              index,
              currentSong,
              playerState,
            ),
          );
        } else {
          return ReorderableListView.builder(
            scrollController: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayedQueue.length,

            itemBuilder: (context, index) => _buildQueueTile(
              context,
              ref,
              displayedQueue[index],
              index,
              currentSong,
              playerState,
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
    Song? currentSong,
    PlayerState playerState,
  ) {
    final theme = Theme.of(context);
    final isCurrent = currentSong?.id == song.id;

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
        final originalIndex = playerState.queue.indexWhere((s) => s.id == song.id);
        if (originalIndex != -1) {
          ref.read(playerStateProvider.notifier).skipToQueueItem(originalIndex);
        }
      },
    );
  }

}
