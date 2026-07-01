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


    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // 1. Mesh Background Simulation
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.4),
                  radius: 1.5,
                  colors: [
                    Color(0x33141E32),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.6, 0.4),
                  radius: 1.5,
                  colors: [
                    Color(0x2232143C),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 0),
                  radius: 1.0,
                  colors: [
                    Color(0xCC0A0F1E),
                    AppColors.darkBackground,
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
                // IMPORTANT: sheetScrollController MUST be the controller of the
                // outermost scrollable (CustomScrollView). This is what drives
                // the sheet's drag behaviour.
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withAlpha(220),
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
                      child: ListenableBuilder(
                        listenable: _sheetController,
                        builder: (context, _) {
                          final isExpanded = _sheetController.isAttached
                              ? _sheetController.size > 0.2
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
                                  onTap: () {
                                    if (_sheetController.isAttached) {
                                      _sheetController.animateTo(
                                        isExpanded ? 0.1 : 0.85,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
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
                                            color: AppColors.surfaceContainerHighest,
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
                                                color: AppColors.onSurface.withOpacity(0.8),
                                              ),
                                            ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_down
                                                  : Icons.keyboard_arrow_up,
                                              color: AppColors.onSurfaceVariant,
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
                                            labelColor: AppColors.primary,
                                            unselectedLabelColor: AppColors.onSurfaceVariant,
                                            indicatorColor: AppColors.primary,
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
                                                _buildQueueTab(sheetScrollController),
                                                LyricsView(
                                                  song: song,
                                                  position: playerState.position,
                                                  scrollController: sheetScrollController,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.expand_more, color: AppColors.onSurfaceVariant),
            onPressed: () => context.router.maybePop(),
          ),
          Text(
            'NOW PLAYING',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 2.0,
            ),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).setThemeMode(
                  isDark ? AppThemeMode.light : AppThemeMode.dark);
            },
          ),
        ],
      ),
    );
  }


  Widget _buildQueueTab(ScrollController? scrollController) {
    return Consumer(
      builder: (context, ref, child) {
        final playerState = ref.watch(playerStateProvider);
        final displayedQueue = playerState.playbackQueue;
        final currentSong = playerState.currentSong;

        if (displayedQueue.isEmpty) {
          return const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white70)));
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
            color: Colors.grey[800],
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Colors.white : Colors.white70,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? Colors.white70 : Colors.white38,
        ),
      ),
      trailing: isCurrent
          ? const Icon(Icons.volume_up, color: Colors.white)
          : IconButton(
              icon: const Icon(Icons.close, color: Colors.white30, size: 20),
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
