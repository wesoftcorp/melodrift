import 'dart:ui';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/home_data.dart';
import '../providers/player_notifier.dart';
import '../widgets/song_card.dart';
import '../widgets/album_card.dart';
import '../widgets/mood_card.dart';
import 'details_screen.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------


/// Holds the set of selected language filters. {'All'} means no filter.
final homeLanguageProvider = StateProvider<Set<String>>((ref) => {'All'});

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
            await prefs.remove('home_feed_cache_date');
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
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Glassmorphism App Bar ────────────────────────────────
                _buildAppBar(context, ref, isDark),

                // ── Featured Cascade Carousel ────────────────────────────
                _buildFeaturedCascade(feed),

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
                  onSeeAll: () => _openDetails(
                    context,
                    const DetailsScreen(
                      id: 'moods',
                      title: 'Moods & Genres',
                      type: 'mood',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 48,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MoodCard(mood: feed.moods[index]),
                      childCount: feed.moods.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
                    // Logo / greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Melodrift',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            _getGreeting(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Theme toggle
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                      onPressed: () {
                        final notifier = ref.read(themeProvider.notifier);
                        notifier.setThemeMode(
                            isDark ? AppThemeMode.light : AppThemeMode.dark);
                      },
                    ),
                    // Notifications placeholder
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                          color: theme.colorScheme.onSurface),
                      onPressed: () {},
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

  // ── Featured Cascade Carousel ─────────────────────────────────────────────
  Widget _buildFeaturedCascade(HomeData feed) {
    final items = [
      if (feed.featuredPlaylist != null) feed.featuredPlaylist!,
      ...feed.newReleases,
    ];
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: _FeaturedCascade(items: items.take(9).toList()),
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
              onTap: () => ref.read(playerStateProvider.notifier).playSong(song),
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
                          ? NetworkImage(artist.artworkUrl)
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
                children: colSongs.map((song) {
                  return SizedBox(
                    height: 64,
                    child: SongCard(song: song, size: 48),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return SliverToBoxAdapter(
      child: Padding(
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
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
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
                ),
                child: const Text('See all'),
              ),
          ],
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

void _openDetails(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

// ---------------------------------------------------------------------------
// Featured Cascade Carousel Widget
// ---------------------------------------------------------------------------

class _FeaturedCascade extends StatefulWidget {
  final List<Album> items;

  const _FeaturedCascade({required this.items});

  @override
  State<_FeaturedCascade> createState() => _FeaturedCascadeState();
}

class _FeaturedCascadeState extends State<_FeaturedCascade> {
  int _currentPage = 0;
  Timer? _timer;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (widget.items.isEmpty) return;
      setState(() {
        _currentPage = (_currentPage + 1) % widget.items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final cardSize = width > 700 ? 240.0 : (width * 0.58).clamp(188.0, 230.0);
    final sideSize = cardSize * 0.72;
    final sideOffset = cardSize * 0.58;
    final leftIndex = _circularIndex(_currentPage - 1);
    final rightIndex = _circularIndex(_currentPage + 1);
    final farLeftIndex = _circularIndex(_currentPage - 2);
    final farRightIndex = _circularIndex(_currentPage + 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _timer?.cancel(),
          onHorizontalDragUpdate: (details) => _dragDx += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (_) {
            if (_dragDx.abs() > 36) {
              _rotate(_dragDx < 0 ? 1 : -1);
            }
            _dragDx = 0;
            _startTimer();
          },
          child: SizedBox(
            height: cardSize + 54,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                if (widget.items.length > 3)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(-sideOffset * 1.58, 0),
                      child: _CascadeTile(
                        album: widget.items[farLeftIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _setPage(farLeftIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 1)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(-sideOffset, 0),
                      child: _CascadeTile(
                        album: widget.items[leftIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _setPage(leftIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 4)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(sideOffset * 1.58, 0),
                      child: _CascadeTile(
                        album: widget.items[farRightIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _setPage(farRightIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 2)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(sideOffset, 0),
                      child: _CascadeTile(
                        album: widget.items[rightIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _setPage(rightIndex),
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _CascadeTile(
                    key: ValueKey(widget.items[_currentPage].id),
                    album: widget.items[_currentPage],
                    size: cardSize,
                    opacity: 1,
                    showDetails: true,
                    onTap: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: widget.items[_currentPage].id,
                        title: widget.items[_currentPage].title,
                        artworkUrl: widget.items[_currentPage].artworkUrl,
                        type: 'album',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentPage == index ? 16 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _circularIndex(int index) => (index % widget.items.length + widget.items.length) % widget.items.length;

  void _rotate(int delta) => _setPage(_circularIndex(_currentPage + delta));

  void _setPage(int index) {
    if (!mounted || widget.items.isEmpty) return;
    setState(() {
      _currentPage = _circularIndex(index);
    });
  }
}

class _CascadeTile extends StatelessWidget {
  final Album album;
  final double size;
  final double opacity;
  final bool showDetails;
  final VoidCallback onTap;

  const _CascadeTile({
    required this.album,
    required this.size,
    required this.opacity,
    required this.onTap,
    this.showDetails = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(showDetails ? 0.35 : 0.18),
                blurRadius: showDetails ? 22 : 12,
                offset: Offset(0, showDetails ? 12 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                album.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.artworkUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note, size: 56),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note, size: 56),
                      ),
                if (showDetails)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.82),
                        ],
                      ),
                    ),
                  ),
                if (showDetails)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'FEATURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          album.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (album.artist.isNotEmpty)
                          Text(
                            album.artist,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
