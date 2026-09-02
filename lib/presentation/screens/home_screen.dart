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
import '../widgets/album_card.dart';
import '../providers/player_notifier.dart';

import '../widgets/song_card.dart';
import '../widgets/mood_card.dart'; // exports MoodCard + HorizontalMoodRow
import 'details_screen.dart';

import '../widgets/home/home_trending_cascade.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/theme/tokens.dart';


const List<Song> _kDefaultTrendingSongs = [
  Song(
    id: 'jiosaavn_kesariya',
    title: 'Kesariya',
    artist: 'Arijit Singh, Pritam',
    album: 'Brahmastra',
    duration: Duration(minutes: 4, seconds: 28),
    artworkUrl: 'https://c.saavncdn.com/978/Brahmastra-Hindi-2022-20220717092820-500x500.jpg',
    videoId: 'kesariya',
    source: 'JioSaavn',
  ),
  Song(
    id: 'jiosaavn_chaleya',
    title: 'Chaleya',
    artist: 'Arijit Singh, Shilpa Rao, Anirudh Ravichander',
    album: 'Jawan',
    duration: Duration(minutes: 3, seconds: 20),
    artworkUrl: 'https://c.saavncdn.com/026/Chaleya-From-Jawan-Hindi-2023-20230814014339-500x500.jpg',
    videoId: 'chaleya',
    source: 'JioSaavn',
  ),
  Song(
    id: 'jiosaavn_vaaste',
    title: 'Vaaste',
    artist: 'Dhvani Bhanushali, Nikhil D\'Souza',
    album: 'Vaaste',
    duration: Duration(minutes: 3, seconds: 15),
    artworkUrl: 'https://c.saavncdn.com/191/Vaaste-Hindi-2019-20190406085521-500x500.jpg',
    videoId: 'GO_qN_Hd',
    source: 'JioSaavn',
  ),
  Song(
    id: 'jiosaavn_heeriye',
    title: 'Heeriye',
    artist: 'Jasleen Royal, Arijit Singh',
    album: 'Heeriye',
    duration: Duration(minutes: 3, seconds: 14),
    artworkUrl: 'https://c.saavncdn.com/022/Heeriye-feat-Arijit-Singh-Hindi-2023-20230724123537-500x500.jpg',
    videoId: 'heeriye',
    source: 'JioSaavn',
  ),
  Song(
    id: 'jiosaavn_apna_bana_le',
    title: 'Apna Bana Le',
    artist: 'Arijit Singh, Sachin-Jigar',
    album: 'Bhediya',
    duration: Duration(minutes: 4, seconds: 21),
    artworkUrl: 'https://c.saavncdn.com/815/Bhediya-Hindi-2022-20221105073004-500x500.jpg',
    videoId: 'apna_bana_le',
    source: 'JioSaavn',
  ),
  Song(
    id: 'jiosaavn_raataan_lambiyan',
    title: 'Raataan Lambiyan',
    artist: 'Tanishk Bagchi, Jubin Nautiyal, Asees Kaur',
    album: 'Shershaah',
    duration: Duration(minutes: 3, seconds: 50),
    artworkUrl: 'https://c.saavncdn.com/238/Shershaah-Original-Motion-Picture-Soundtrack--Hindi-2021-20210815181610-500x500.jpg',
    videoId: 'raataan_lambiyan',
    source: 'JioSaavn',
  ),
];

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

  HomeLanguageNotifier(this._prefs) : super(_loadInitial(_prefs));

  static Set<String> _loadInitial(SharedPreferences prefs) {
    final list = prefs.getStringList(_key);
    // Default to Hindi if no preference has been set yet
    if (list == null || list.isEmpty) return {'Hindi'};
    return list.toSet();
  }

  void toggle(String lang) {
    if (lang == 'All') {
      state = {'All'};
    } else {
      final next = Set<String>.from(state)..remove('All');
      if (next.contains(lang)) {
        next.remove(lang);
        if (next.isEmpty) next.add('All');
      } else {
        next.add(lang);
      }
      state = next;
    }
    _prefs.setStringList(_key, state.toList());
  }

  void setLanguages(Set<String> langs) {
    state = langs.isEmpty ? {'All'} : langs;
    _prefs.setStringList(_key, state.toList());
  }

  bool isSelected(String lang) => state.contains(lang);
}


/// Public list of all available song language options.
// ignore: constant_identifier_names
const kLanguageOptions = [
  'All',
  'Hindi',
  'English',
  'Punjabi',
  'Tamil',
  'Telugu',
  'Malayalam',
  'Kannada',
  'Bengali',
  'Marathi',
  'Gujarati',
  'Bhojpuri',
  'Haryanvi',
  'Rajasthani',
  'Urdu',
  'Assamese',
  'Odia',
  'Nepali',
  'Spanish',
  'Korean',
  'Japanese',
];


final homeFeedProvider = FutureProvider<HomeData>((ref) async {
  final langSet = ref.watch(homeLanguageProvider);
  final langParam = (langSet.contains('All') || langSet.isEmpty)
      ? null
      : langSet.join(',');
  return ref.watch(musicRepositoryProvider).getHomeFeed(language: langParam);
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
  void initState() {
    super.initState();
    _checkDailyRefresh();
  }

  Future<void> _checkDailyRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final lastRefreshed = prefs.getString('last_home_feed_refresh_date');
      if (lastRefreshed != todayKey) {
        await prefs.setString('last_home_feed_refresh_date', todayKey);
        ref.invalidate(homeFeedProvider);
      }
    } catch (_) {}
  }

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
      body: feedAsync.when(
          loading: () => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/melodrift.png', width: 64, height: 64),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your feed…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  'Check your connection and try again.',
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
            bool isSingleTrack(Song s) => s.title.isNotEmpty && (s.duration == Duration.zero || s.duration.inMinutes <= 20);
            final availableTrending = [
              ...feed.trendingSongs,
              ...feed.quickPicks,
              ...feed.charts,
              ...feed.indianMusic,
              ...feed.spotifyTopHits,
            ].where(isSingleTrack).toList();

            final trendingSingleSongs = availableTrending.isNotEmpty
                ? availableTrending
                : _kDefaultTrendingSongs;

            final quickPickSongs = feed.quickPicks
                .where(isSingleTrack)
                .toList();

            final indianSongs = feed.indianMusic
                .where(isSingleTrack)
                .toList();
            final chartSongs = feed.charts
                .where(isSingleTrack)
                .toList();
            final forgottenSongs = feed.forgottenFavorites
                .where(isSingleTrack)
                .toList();
            final spotifySongs = feed.spotifyTopHits

                .where(isSingleTrack)
                .toList();
            final soundCloudSongs = feed.soundCloudLounge
                .where(isSingleTrack)
                .toList();
            final top100InternationalSongs = feed.top100International
                .where(isSingleTrack)
                .toList();
            final punjabiSongs = feed.punjabiHits
                .where(isSingleTrack)
                .toList();
            final romanticSongs = feed.romanticMelodies
                .where(isSingleTrack)
                .toList();
            final partySongs = feed.partyDanceMix
                .where(isSingleTrack)
                .toList();

            final hindiHitSongs = feed.hindiHits
                .where(isSingleTrack)
                .toList();
            final sufiSongs = feed.sufiGhazals
                .where(isSingleTrack)
                .toList();
            final devotionalSongs = feed.devotionalBhakti
                .where(isSingleTrack)
                .toList();
            final retro90sSongs = feed.retro90s
                .where(isSingleTrack)
                .toList();
            final bhangraSongs = feed.bhangraDhol
                .where(isSingleTrack)
                .toList();
            final indieHindiSongs = feed.indieHindi
                .where(isSingleTrack)
                .toList();
            final spotifyIndiaSongs = feed.spotifyIndiaTop50
                .where(isSingleTrack)
                .toList();
            final newMusicFridaySongs = feed.newMusicFridayIndia
                .where(isSingleTrack)
                .toList();

            return RefreshIndicator(
              color: const Color(0xFFFF5F1F),
              onRefresh: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final keys = prefs.getKeys().where((k) => k.startsWith('home_feed_cache_')).toList();
                  for (final k in keys) { await prefs.remove(k); }
                } catch (_) {}
                return ref.refresh(homeFeedProvider.future);
              },
              child: Stack(
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
                if (trendingSingleSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Melodrift Trending Music',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'trending_songs',
                        title: 'Melodrift Trending Music',
                        type: 'songList',
                        preloadedSongs: trendingSingleSongs,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Builder(builder: (context) {
                        final topTrending = trendingSingleSongs.take(30).toList();
                        return HomeTrendingCascade(
                          songs: topTrending,
                          onSongTap: (song) {
                            final index = topTrending.indexWhere((s) => s.id == song.id);
                            ref.read(playerStateProvider.notifier).playQueue(
                              topTrending,
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
                  final userHistory = (historyAsync.value ?? [])
                      .where(isSingleTrack)
                      .toList();
                  final feedListenAgain = feed.listenAgain
                      .where(isSingleTrack)
                      .toList();
                  final listenAgainSongs = userHistory.isNotEmpty ? userHistory : feedListenAgain;
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


                // ── Hindi Hits 🎵 ────────────────────────────────────────
                if (hindiHitSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    '🎵 Hindi Hits',
                    textColor: const Color(0xFFFF9933),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'hindi_hits',
                        title: 'Hindi Hits',
                        type: 'songList',
                        preloadedSongs: hindiHitSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, hindiHitSongs),
                ],

                // ── Quick Picks ──────────────────────────────────────────
                if (quickPickSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Quick Picks',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'quick_picks',
                        title: 'Quick Picks',
                        type: 'songList',
                        preloadedSongs: quickPickSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, quickPickSongs),
                ],

                // ── Spotify India Top 50 🇮🇳 ──────────────────────────────
                if (spotifyIndiaSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'India Top 50',
                    textColor: const Color(0xFF1DB954),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'spotify_india_top_50',
                        title: 'India Top 50',
                        type: 'songList',
                        preloadedSongs: spotifyIndiaSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, spotifyIndiaSongs),
                ],

                // ── New Music Friday India 🌟 ─────────────────────────────
                if (newMusicFridaySongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'New Music Friday India',
                    textColor: const Color(0xFFFF5F1F),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'new_music_friday_india',
                        title: 'New Music Friday India',
                        type: 'songList',
                        preloadedSongs: newMusicFridaySongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, newMusicFridaySongs),
                ],

                // ── Personalized Recommendations (YouTube-style) ─────────
                ref.watch(personalizedRecommendationsProvider).when(
                  data: (rec) {
                    final recSongs = rec.songs
                        .where(isSingleTrack)
                        .toList();
                    if (recSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverMainAxisGroup(
                      slivers: [
                        _buildSectionHeader(

                          rec.title,
                          onSeeAll: () => _openDetails(
                            context,
                            DetailsScreen(
                              id: 'personalized_rec',
                              title: rec.title,
                              type: 'songList',
                              preloadedSongs: recSongs,
                            ),
                          ),
                        ),
                        _buildMultiRowSongList(context, ref, recSongs),
                      ],
                    );
                  },
                  loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                // ── Fresh Releases ───────────────────────────────────────
                if (feed.newReleases.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Fresh Releases',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'fresh_releases',
                        title: 'Fresh Releases',
                        type: 'albumList',
                        preloadedAlbums: feed.newReleases,
                      ),
                    ),
                  ),
                  _buildAlbumRow(context, feed.newReleases),
                ],

                // ── Top 100 Hindi Blockbusters ───────────────────────────
                if (top100InternationalSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Top 100 Hindi Blockbusters',
                    textColor: const Color(0xFF00D2FF),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'top_100_blockbusters',
                        title: 'Top 100 Hindi Blockbusters',
                        type: 'songList',
                        preloadedSongs: top100InternationalSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, top100InternationalSongs),
                ],

                // ── Punjabi Hits & Bangers ───────────────────────────────
                if (punjabiSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Punjabi Hits & Bangers',
                    textColor: const Color(0xFFFF5F1F),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'punjabi_hits',
                        title: 'Punjabi Hits & Bangers',
                        type: 'songList',
                        preloadedSongs: punjabiSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, punjabiSongs),
                ],

                // ── Bhangra & Dhol 🥁 ────────────────────────────────────
                if (bhangraSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Bhangra & Dhol 🥁',
                    textColor: const Color(0xFFFF8800),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'bhangra_dhol',
                        title: 'Bhangra & Dhol',
                        type: 'songList',
                        preloadedSongs: bhangraSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, bhangraSongs),
                ],

                // ── Romantic Melodies ────────────────────────────────────
                if (romanticSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Romantic Melodies',
                    textColor: const Color(0xFFFF69B4),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'romantic_melodies',
                        title: 'Romantic Melodies',
                        type: 'songList',
                        preloadedSongs: romanticSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, romanticSongs),
                ],

                // ── Party & Dance Club Mix ───────────────────────────────
                if (partySongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Party & Dance Mix',
                    textColor: const Color(0xFFFFD700),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'party_dance_mix',
                        title: 'Party & Dance Mix',
                        type: 'songList',
                        preloadedSongs: partySongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, partySongs),
                ],

                // ── Sufi & Ghazals 🕉 ────────────────────────────────────
                if (sufiSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Sufi & Ghazals 🕉',
                    textColor: const Color(0xFF00E5FF),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'sufi_ghazals',
                        title: 'Sufi & Ghazals',
                        type: 'songList',
                        preloadedSongs: sufiSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, sufiSongs),
                ],

                // ── Devotional & Bhakti 🙏 ────────────────────────────────
                if (devotionalSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Devotional & Bhakti 🙏',
                    textColor: const Color(0xFFFF9933),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'devotional_bhakti',
                        title: 'Devotional & Bhakti',
                        type: 'songList',
                        preloadedSongs: devotionalSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, devotionalSongs),
                ],

                // ── 90s Retro Throwback 🎤 ───────────────────────────────
                if (retro90sSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    '90s Retro Throwback 🎤',
                    textColor: const Color(0xFFE040FB),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'retro_90s',
                        title: '90s Retro Throwback',
                        type: 'songList',
                        preloadedSongs: retro90sSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, retro90sSongs),
                ],

                // ── Indian Music ─────────────────────────────────────────
                if (indianSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Indian Music',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'indian_music',
                        title: 'Indian Music',
                        type: 'songList',
                        preloadedSongs: indianSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, indianSongs),
                ],

                // ── Trending Charts ──────────────────────────────────────
                if (chartSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Trending Charts',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'charts',
                        title: 'Trending Charts',
                        type: 'songList',
                        preloadedSongs: chartSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, chartSongs),
                ],

                // ── Forgotten Favorites ──────────────────────────────────
                if (forgottenSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Forgotten favorites',
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'forgotten_favorites',
                        title: 'Forgotten favorites',
                        type: 'songList',
                        preloadedSongs: forgottenSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, forgottenSongs),
                ],

                // ── Melodrift Global Top Hits ────────────────────────────
                if (spotifySongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Melodrift Global Top Hits',
                    textColor: const Color(0xFF1DB954),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'global_top_hits',
                        title: 'Melodrift Global Top Hits',
                        type: 'songList',
                        preloadedSongs: spotifySongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, spotifySongs),
                ],

                // ── Indie Hindi 🎧 ───────────────────────────────────────
                if (indieHindiSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Indie Hindi 🎧',
                    textColor: const Color(0xFF00D2FF),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'indie_hindi',
                        title: 'Indie Hindi',
                        type: 'songList',
                        preloadedSongs: indieHindiSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, indieHindiSongs),
                ],

                // ── Lo-Fi Lounge & Chill Beats ───────────────────────────
                if (soundCloudSongs.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Lo-Fi Lounge & Chill Beats',
                    textColor: const Color(0xFFFF5500),
                    onSeeAll: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: 'lofi_lounge',
                        title: 'Lo-Fi Lounge & Chill Beats',
                        type: 'songList',
                        preloadedSongs: soundCloudSongs,
                      ),
                    ),
                  ),
                  _buildMultiRowSongList(context, ref, soundCloudSongs),
                ],


                // ── Featured Albums & Playlists (Albums prioritized first) ───
                Builder(builder: (context) {
                  final Map<String, Album> combinedMap = {};
                  // Priority 1: Albums For You
                  for (final a in feed.albumsForYou) {
                    if (a.tracks.length >= 3 || a.songCount >= 3) {
                      combinedMap[a.id] = a;
                    }
                  }
                  // Priority 2: Featured Playlists
                  for (final a in feed.featuredPlaylistsForYou) {
                    if (!combinedMap.containsKey(a.id) && (a.tracks.length >= 3 || a.songCount >= 3)) {
                      combinedMap[a.id] = a;
                    }
                  }
                  final mergedAlbums = combinedMap.values.toList();
                  if (mergedAlbums.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  return SliverMainAxisGroup(
                    slivers: [
                      _buildSectionHeader(
                        'Albums & Featured Playlists',
                        textColor: const Color(0xFF00E5FF),
                        onSeeAll: () => _openDetails(
                          context,
                          DetailsScreen(
                            id: 'featured_albums_playlists',
                            title: 'Albums & Featured Playlists',
                            type: 'albumList',
                            preloadedAlbums: mergedAlbums,
                          ),
                        ),
                      ),
                      _buildAlbumRow(context, mergedAlbums),
                    ],
                  );
                }),

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
        ),
        );
          },
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
                          tooltip: 'Notifications',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notifications coming soon 🔔'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
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
        height: 76,
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
        height: 276,
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
                    height: 66,
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

  Widget _buildAlbumRow(BuildContext context, List<Album> albums) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 185,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            return AlbumCard(album: albums[index], size: 120);
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
    if (hour < 5)  return 'Good Night 🌙';
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon ⛅';
    if (hour < 21) return 'Good Evening 🌇';
    return 'Good Night 🌙';
  }
}

void _openDetails(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

