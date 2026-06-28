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
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('No song playing')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic blurred background
          Positioned.fill(
            child: song.artworkUrl.isNotEmpty
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: CachedNetworkImage(
                      imageUrl: song.artworkUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.6),
                      colorBlendMode: BlendMode.darken,
                    ),
                  )
                : Container(color: Colors.grey[900]),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

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

          // 3. Sliding tab panel (UP NEXT, LYRICS, RELATED)
          DefaultTabController(
            length: 3,
            child: DraggableScrollableSheet(
              initialChildSize: 0.12,
              minChildSize: 0.12,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                final theme = Theme.of(context);
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(200),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(128),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                    children: [
                      // Grab handle & tabs inside SingleChildScrollView to align scroll action
                      SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        controller: scrollController,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TabBar(
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                              indicatorColor: theme.colorScheme.primary,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelStyle: AppTextStyles.monoSectionHeader,
                              tabs: const [
                                Tab(text: 'UP NEXT'),
                                Tab(text: 'LYRICS'),
                                Tab(text: 'RELATED'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildQueueTab(scrollController),
                            LyricsView(
                              song: song,
                              position: playerState.position,
                              scrollController: scrollController,
                            ),
                            _buildRelatedTab(song.videoId, scrollController),
                          ],
                        ),
                      ),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
            onPressed: () => context.router.maybePop(),
          ),
          Text(
            'NOW PLAYING',
            style: AppTextStyles.monoSectionHeader.copyWith(color: Colors.white70),
          ),
          const SizedBox(width: 48), // Spacer to balance back button
        ],
      ),
    );
  }

  Widget _buildQueueTab(ScrollController scrollController) {
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

  Widget _buildRelatedTab(String videoId, ScrollController scrollController) {
    return Consumer(
      builder: (context, ref, child) {
        final relatedAsync = ref.watch(relatedSongsProvider(videoId));
        return relatedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (err, _) => Center(child: Text('Error loading recommendations: $err', style: const TextStyle(color: Colors.white70))),
          data: (songs) {
            if (songs.isEmpty) {
              return const Center(child: Text('No recommendations found', style: TextStyle(color: Colors.white70)));
            }
            return ListView.builder(
              controller: scrollController,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
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
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38),
                  ),
                  onTap: () {
                    // Play the selected song and set the rest of related list as queue
                    ref.read(playerStateProvider.notifier).playQueue(songs, initialIndex: index);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
