import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../providers/player_notifier.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_artwork_view.dart';

@RoutePage()
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic blurred background
          Positioned.fill(
            child: song.artworkUrl.isNotEmpty
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: CachedNetworkImage(
                      imageUrl: song.artworkUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    ),
                  )
                : Container(color: Colors.grey[900]),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

          // 2. Main content UI
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(context),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: [
                      const PlayerArtworkView(),
                      LyricsView(song: song, position: playerState.position),
                    ],
                  ),
                ),
                const PlayerControls(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text(
                        'LYRICS',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
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
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play, color: Colors.white),
            onPressed: () => _showQueue(context),
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.7,
        child: QueueSheet(),
      ),
    );
  }
}
