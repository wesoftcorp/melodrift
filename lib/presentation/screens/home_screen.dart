import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/home_data.dart';

import '../providers/player_notifier.dart';
import '../widgets/song_card.dart';
import '../widgets/album_card.dart';
import '../widgets/mood_card.dart'; // exports MoodCard + HorizontalMoodRow
import 'details_screen.dart';
import '../widgets/home/home_trending_cascade.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../core/theme/tokens.dart';


// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------


/// Holds the set of selected language filters. {'All'} means no filter.
/// Persisted language filter — survives app restarts via SharedPreferences.
final homeLanguageProvider = StateNotifierProvider<HomeLanguageNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HomeLanguageNotifier(prefs);
});

class HomeLanguageNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;
  static const _key = 'home_language_filter';

  HomeLanguageNotifier(this._prefs)
      : super(_load(_prefs));

  static Set<String> _load(SharedPreferences prefs) {
    final saved = prefs.getStringList(_key);
    if (saved == null || saved.isEmpty) return {'All'};
    return Set<String>.from(saved);
  }

  void setLanguages(Set<String> langs) {
    state = langs.isEmpty ? {'All'} : langs;
    _prefs.setStringList(_key, state.toList());
  }
}

/// Public list of language options (also consumed by SettingsScreen).
// ignore: constant_identifier_names
const kLanguageOptions = ['All', 'English', 'Hindi', 'Nepali'];

final homeFeedProvider = FutureProvider<HomeData>((ref) async {
  final repository = ref.watch(musicRepositoryProvider);
  final languages = ref.watch(homeLanguageProvider);

  // Pass null when "All" is selected — API returns everything
  final lang = (languages.contains('All') || languages.isEmpty)
      ? null
      : languages.join(' ');

  return repository.getHomeFeed(language: lang);
});



// ---------------------------------------------------------------------------
// Home Screen
// ---------------------------------------------------------------------------

@RoutePage()
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(homeFeedProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            // Clear all home feed cache keys so a fresh decorated feed is fetched
            await prefs.remove('home_feed_cache_date_v5');
            await prefs.remove('home_feed_cache_date_v7');
            await prefs.remove('home_feed_cache_data_all');
            await prefs.remove('home_feed_cache_data_English');
            await prefs.remove('home_feed_cache_data_Hindi');
            await prefs.remove('home_feed_cache_data_Nepali');
            await prefs.remove('home_feed_cache_data_English Hindi');
            await prefs.remove('home_feed_cache_data_English Nepali');
            await prefs.remove('home_feed_cache_data_Hindi Nepali');
            await prefs.remove('home_feed_cache_data_English Hindi Nepali');
          } catch (_) {}
          return ref.refresh(homeFeedProvider.future);
        },
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Could not load feed',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(homeFeedProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (feed) {
            return Stack(
              children: [
                if (isDark)
                  Positioned(
                    top: -150,
                    left: -100,
                    child: IgnorePointer(
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withAlpha(25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                // ── Glassmorphism App Bar ────────────────────────────────
                _buildAppBar(context, ref, isDark),

                // ── Greeting Title ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      _getGreeting(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),


                // ── Melodrift Trending Music ─────────────────────────────
                if (feed.trendingSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Melodrift Trending Music',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'trending_songs',
                        title: 'Melodrift Trending Music',
                        type: 'songList',
                        preloadedSongs: feed.trendingSongs,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Builder(builder: (context) {
                        final trendingSongs = feed.trendingSongs.take(30).toList();
                        return HomeTrendingCascade(
                          songs: trendingSongs,
                          onSongTap: (song) {
                            final index = trendingSongs.indexWhere((s) => s.id == song.id);
                            ref.read(playerStateProvider.notifier).playQueue(
                              trendingSongs,
                              initialIndex: index >= 0 ? index : 0,
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ],

                // ── Listen Again (User History) ─────────────────────────
                Builder(builder: (context) {
                  final historyAsync = ref.watch(listeningHistoryProvider);
                  final userHistory = historyAsync.value ?? [];
                  final listenAgainSongs = userHistory.isNotEmpty ? userHistory : feed.listenAgain;
                  if (listenAgainSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverMainAxisGroup(
                    slivers: [
                      _buildSectionHeader(
                        'Listen Again',
                        onSeeAll: () => _openDetails(
                          context,
                          DetailsScreen(
                            id: 'listen_again',
                            title: 'Listen Again',
                            type: 'songList',
                            preloadedSongs: listenAgainSongs,
                          ),
                        ),
                      ),
                      _buildCompactSongRow(context, ref, listenAgainSongs),
                    ],
                  );
                }),


                // ── Quick Picks ──────────────────────────────────────────
                _buildSectionHeader(
                  'Quick Picks',
                  onSeeAll: () => _openDetails(
                    context,
                    DetailsScreen(
                      id: 'quick_picks',
                      title: 'Quick Picks',
                      type: 'songList',
                      preloadedSongs: feed.quickPicks,
                    ),
                  ),
                ),
                _buildMultiRowSongList(context, ref, feed.quickPicks),

                // ── Featured Playlists for You ───────────────────────────
                if (feed.featuredPlaylistsForYou.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Featured playlists for you',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'featured_playlists',
                        title: 'Featured playlists for you',
                        type: 'albumList',
                        preloadedAlbums: feed.featuredPlaylistsForYou,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 215,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: feed.featuredPlaylistsForYou.length,
                        itemBuilder: (context, index) => AlbumCard(
                          album: feed.featuredPlaylistsForYou[index],
                          size: 140.0,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Indian Music ─────────────────────────────────────────
                if (feed.indianMusic.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Indian Music',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'indian_music',
                        title: 'Indian Music',
                        type: 'songList',
                        preloadedSongs: feed.indianMusic,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, feed.indianMusic),
                ],

                // ── New Releases ─────────────────────────────────────────
                _buildSectionHeader(
                  'New Releases',
                  onSeeAll: () => _openDetails(
                    context,
                    DetailsScreen(
                      id: 'new_releases',
                      title: 'New Releases',
                      type: 'albumList',
                      preloadedAlbums: feed.newReleases,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 215,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: feed.newReleases.length,
                      itemBuilder: (context, index) => AlbumCard(
                        album: feed.newReleases[index],
                        size: 140.0,
                      ),
                    ),
                  ),
                ),

                // ── Trending Charts ──────────────────────────────────────
                _buildSectionHeader(
                  'Trending Charts',
                  onSeeAll: () => _openDetails(
                    context,
                    DetailsScreen(
                      id: 'charts',
                      title: 'Trending Charts',
                      type: 'songList',
                      preloadedSongs: feed.charts,
                    ),
                  ),
                ),
                _buildMultiRowSongList(context, ref, feed.charts),

                // ── Forgotten Favorites ──────────────────────────────────
                if (feed.forgottenFavorites.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Forgotten favorites',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'forgotten_favorites',
                        title: 'Forgotten favorites',
                        type: 'songList',
                        preloadedSongs: feed.forgottenFavorites,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, feed.forgottenFavorites),
                ],

                // ── Albums for You (Personalized for User Repeated Listens) ──
                Builder(builder: (context) {
                  final historyAsync = ref.watch(listeningHistoryProvider);
                  final userHistory = historyAsync.value ?? [];
                  
                  // Extract top repeated artists from history
                  final Map<String, int> artistCounts = {};
                  for (final s in userHistory) {
                    final firstArtist = s.artist.split(',').first.trim();
                    if (firstArtist.isNotEmpty) {
                      artistCounts[firstArtist] = (artistCounts[firstArtist] ?? 0) + 1;
                    }
                  }
                  
                  final topArtists = artistCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  
                  final topArtistName = topArtists.isNotEmpty ? topArtists.first.key : '';

                  if (topArtistName.isEmpty) {
                    if (feed.albumsForYou.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverMainAxisGroup(
                      slivers: [
                        _buildSectionHeader(
                          'Albums for you',
                          onSeeAll: () => _openDetails(
                            context,
                            DetailsScreen(
                              id: 'albums_for_you',
                              title: 'Albums for you',
                              type: 'albumList',
                              preloadedAlbums: feed.albumsForYou,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 215,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: feed.albumsForYou.length,
                              itemBuilder: (context, index) => AlbumCard(
                                album: feed.albumsForYou[index],
                                size: 140.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return FutureBuilder<List<Album>>(
                    future: ref.read(musicRepositoryProvider).searchAlbums(topArtistName),
                    builder: (context, snapshot) {
                      final albums = (snapshot.data?.isNotEmpty == true) ? snapshot.data! : feed.albumsForYou;
                      if (albums.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                      return SliverMainAxisGroup(
                        slivers: [
                          _buildSectionHeader(
                            'Albums for you ($topArtistName & more)',
                            onSeeAll: () => _openDetails(
                              context,
                              DetailsScreen(
                                id: 'albums_for_you',
                                title: 'Albums for you',
                                type: 'albumList',
                                preloadedAlbums: albums,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 215,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: albums.length,
                                itemBuilder: (context, index) => AlbumCard(
                                  album: albums[index],
                                  size: 140.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }),




                // ── Moods & Genres ───────────────────────────────────────
                _buildSectionHeader(
                  'Moods & Genres',
                  textColor: const Color(0xFFFF5F1F),
                  onSeeAll: () => _openDetails(
                    context,
                    DetailsScreen(
                      id: 'moods',
                      title: 'Moods & Genres',
                      type: 'moodList',
                      preloadedMoods: feed.moods,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: HorizontalMoodRow(moods: feed.moods),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 180)),
              ],
            ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Glassmorphism SliverAppBar ─────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, WidgetRef ref, bool isDark) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      expandedHeight: 60,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.7),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.25),
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    // Logo Image
                    ClipOval(
                      child: Image.asset(
                        'assets/images/melodrift.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const Spacer(),
                    // Center title "Melodrift"
                    Text(
                      'Melodrift',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: const Color(0xFFFF5F1F),
                        fontSize: 24,
                      ),
                    ),
                    const Spacer(),
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: const Color(0xFFFF5F1F),
                            size: 22,
                          ),
                          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                          onPressed: () {
                            final notifier = ref.read(themeProvider.notifier);
                            notifier.setThemeMode(
                                isDark ? AppThemeMode.light : AppThemeMode.dark);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFFFF5F1F),
                            size: 22,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  // ── Compact Song Row (Listen Again) ───────────────────────────────────────
  Widget _buildCompactSongRow(BuildContext context, WidgetRef ref, List<Song> songs) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return GestureDetector(
              onTap: () => ref.read(playerStateProvider.notifier).playQueue(songs, initialIndex: index),
              child: Container(
                width: 220,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: song.artworkUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: song.artworkUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: Theme.of(context).colorScheme.surface,
                                child: const Icon(Icons.music_note),
                              ),
                            )
                          : Container(
                              width: 72,
                              height: 72,
                              color: Theme.of(context).colorScheme.surface,
                              child: const Icon(Icons.music_note),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }



  /// Groups songs into columns of 4 and renders a horizontal scrollable list.
  Widget _buildMultiRowSongList(BuildContext context, WidgetRef ref, List<Song> songs) {
    final groups = <List<Song>>[];
    for (var i = 0; i < songs.length; i += 4) {
      final end = (i + 4 < songs.length) ? i + 4 : songs.length;
      groups.add(songs.sublist(i, end));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final columnWidth =
        isDesktop ? (screenWidth - 32) / 4.3 : screenWidth * 0.85;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 270,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: groups.length,
          itemBuilder: (context, colIndex) {
            final colSongs = groups[colIndex];
            return Container(
              width: columnWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(colSongs.length, (rowIndex) {
                  final globalIndex = colIndex * 4 + rowIndex;
                  final song = colSongs[rowIndex];
                  return SizedBox(
                    height: 64,
                    child: SongCard(
                      song: song,
                      size: 48,
                      queue: songs,
                      queueIndex: globalIndex,
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll, Color? textColor}) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 8,
              top: 28,
              bottom: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTextStyles.monoSectionHeader.copyWith(
                      color: textColor ?? const Color(0xFFFF5F1F),
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFFFF5F1F),
                      textStyle: AppTextStyles.labelMedium,
                    ),
                    child: const Text('See all'),
                  ),
              ],
            ),
          );
        },
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

void _openDetails(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

