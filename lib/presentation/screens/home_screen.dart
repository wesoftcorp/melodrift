import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/entities/home_data.dart';
import '../widgets/song_card.dart';
import '../widgets/album_card.dart';
import '../widgets/mood_card.dart';

final homeFeedProvider = FutureProvider<HomeData>((ref) async {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.getHomeFeed();
});

@RoutePage()
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(homeFeedProvider.future),
          child: feedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading home feed: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(homeFeedProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (feed) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _getGreeting(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildSectionTitle('Quick Picks'),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SongCard(song: feed.quickPicks[index]),
                      childCount: feed.quickPicks.take(5).length,
                    ),
                  ),
                  _buildSectionTitle('New Releases'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: feed.newReleases.length,
                        itemBuilder: (context, index) => AlbumCard(album: feed.newReleases[index]),
                      ),
                    ),
                  ),
                  _buildSectionTitle('Trending Charts'),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SongCard(song: feed.charts[index]),
                      childCount: feed.charts.take(5).length,
                    ),
                  ),
                  _buildSectionTitle('Moods & Genres'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => MoodCard(mood: feed.moods[index]),
                        childCount: feed.moods.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
