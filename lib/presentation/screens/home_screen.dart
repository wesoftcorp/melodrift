import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/home_data.dart';
import '../providers/player_notifier.dart';
import '../widgets/song_card.dart';
import '../widgets/album_card.dart';
import '../widgets/mood_card.dart'; // exports MoodCard + HorizontalMoodRow
import 'details_screen.dart';
import '../widgets/home/home_trending_cascade.dart';
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
  final historySongsAsync = ref.watch(listeningHistoryProvider);
  final historySongs = historySongsAsync.value ?? [];

  // Pass null when "All" is selected — API returns everything
  final lang = (languages.contains('All') || languages.isEmpty)
      ? null
      : languages.join(' ');

  final feed = await repository.getHomeFeed(language: lang);

  // Merge history/previously played songs into feed.listenAgain.
  // Deduplicate and prioritize history.
  final List<Song> combinedListenAgain = [];
  final seenIds = <String>{};

  for (final song in historySongs) {
    if (seenIds.add(song.id)) {
      combinedListenAgain.add(song);
    }
  }

  for (final song in feed.listenAgain) {
    if (seenIds.add(song.id)) {
      combinedListenAgain.add(song);
    }
  }

  return HomeData(
    quickPicks: feed.quickPicks,
    newReleases: feed.newReleases,
    charts: feed.charts,
    moods: feed.moods,
    listenAgain: combinedListenAgain.take(15).toList(),
    recommendedArtists: feed.recommendedArtists,
    featuredPlaylist: feed.featuredPlaylist,
    trendingSongs: feed.trendingSongs,
    featuredPlaylistsForYou: feed.featuredPlaylistsForYou,
    indianMusic: feed.indianMusic,
    forgottenFavorites: feed.forgottenFavorites,
    albumsForYou: feed.albumsForYou,
  );
});


// ---------------------------------------------------------------------------
// Home Screen
// ---------------------------------------------------------------------------

@RoutePage()
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                // ── Listen Again ─────────────────────────────────────────
                if (feed.listenAgain.isNotEmpty) ...[  
                  _buildSectionHeader(
                    'Listen Again',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'listen_again',
                        title: 'Listen Again',
                        type: 'songList',
                        preloadedSongs: feed.listenAgain,
                      ),
                    ),
                  ),
                  _buildCompactSongRow(context, ref, feed.listenAgain),
                ],

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

                // ── Albums for You ───────────────────────────────────────
                if (feed.albumsForYou.isNotEmpty) ...[
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

                // ── Recommended Artists ──────────────────────────────────
                if (feed.recommendedArtists.isNotEmpty) ...[  
                  _buildSectionHeader(
                    'Recommended Artists',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'recommended_artists',
                        title: 'Recommended Artists',
                        type: 'songList',
                        preloadedSongs: feed.recommendedArtists
                            .map((artist) => Song(
                                  id: artist.id,
                                  title: artist.name,
                                  artist: artist.subscribers ?? 'Artist',
                                  album: 'Artist',
                                  duration: Duration.zero,
                                  artworkUrl: artist.artworkUrl,
                                  videoId: artist.id,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  _buildArtistRow(context, feed.recommendedArtists),
                ],

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

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
                    Image.asset(
                      'assets/images/melodrift.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
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

  // ── Recommended Artists Row ────────────────────────────────────────────────
  Widget _buildArtistRow(BuildContext context, List<Artist> artists) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: artist.artworkUrl.isNotEmpty
                          ? CachedNetworkImageProvider(artist.artworkUrl)
                          : null,
                      child: artist.artworkUrl.isEmpty
                          ? const Icon(Icons.person, size: 32)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artist.name,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

