import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/entities/mood_category.dart';
import '../../domain/entities/song.dart';
import '../widgets/search_results_view.dart';
import '../widgets/voice_search_sheet.dart';
import '../widgets/song_card.dart';
import '../../core/theme/theme_provider.dart';

import 'home_screen.dart';
import '../../domain/entities/home_data.dart';
import '../providers/player_notifier.dart';


@RoutePage()
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardListenerNode = FocusNode(skipTraversal: true);
  String _submittedQuery = '';
  List<String> _suggestions = [];
  List<String> _history = [];
  Timer? _debounce;
  bool _isFocused = false;

  int _highlightedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _keyboardListenerNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
      if (_focusNode.hasFocus) {
        _highlightedIndex = -1;
      }
    });
    // Do NOT clear _submittedQuery here — that clears results while the user
    // is still tapping the bar to refine. Results are cleared by _onSearchChanged
    // when the user actually edits the text.
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() {
          _suggestions = [];
          _highlightedIndex = -1;
          // User deleted everything — clear the stale results view
          _submittedQuery = '';
        });
        return;
      }
      final repo = ref.read(musicRepositoryProvider);
      final suggestions = await repo.getSearchSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _highlightedIndex = -1;
        });
      }
    });
  }

  Future<void> _loadHistory() async {
    final historyRepo = ref.read(historyRepositoryProvider);
    final history = await historyRepo.getSearchHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _runSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    _controller.text = cleanQuery;
    _focusNode.unfocus();
    setState(() {
      _submittedQuery = cleanQuery;
      _isFocused = false;
      _highlightedIndex = -1;
    });
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.addSearchQuery(cleanQuery);
    await _loadHistory();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _submittedQuery = '';
      _suggestions = [];
      _highlightedIndex = -1;
    });
    _focusNode.unfocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final items = _suggestions.isNotEmpty ? _suggestions : _history;
    if (items.isEmpty) return;

    final logicalKey = event.logicalKey;
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % items.length;
      });
    } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex = _highlightedIndex <= 0 ? items.length - 1 : _highlightedIndex - 1;
      });
    } else if (logicalKey == LogicalKeyboardKey.enter && _highlightedIndex >= 0) {
      _runSearch(items[_highlightedIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _keyboardListenerNode,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              _SearchHeader(onClear: _clearSearch),

               // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _SearchBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: (val) {
                    final items = _suggestions.isNotEmpty ? _suggestions : _history;
                    if (_highlightedIndex >= 0 && _highlightedIndex < items.length) {
                      _runSearch(items[_highlightedIndex]);
                    } else {
                      _runSearch(val);
                    }
                  },
                  onVoiceResult: _runSearch,
                  onBack: (_submittedQuery.isNotEmpty || _isFocused) ? _clearSearch : null,
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              Expanded(
                child: _buildBody(theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    // 1. Results after submit
    if (_submittedQuery.isNotEmpty && !_isFocused) {
      return SearchResultsViewKeyed(query: _submittedQuery);
    }

    // 2. Live suggestions while typing
    if (_isFocused && _controller.text.trim().isNotEmpty) {
      return _SuggestionsList(
        suggestions: _suggestions,
        history: _history,
        highlightedIndex: _highlightedIndex,
        onTap: _runSearch,
        onDeleteHistory: (item) async {
          await ref.read(historyRepositoryProvider).deleteSearchQuery(item);
          await _loadHistory();
        },
      );
    }

    // 3. Default: Trending + Browse All
    return _SearchHomePage(
      history: _history,
      onTap: _runSearch,
      onDeleteHistory: (item) async {
        await ref.read(historyRepositoryProvider).deleteSearchQuery(item);
        await _loadHistory();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHeader extends ConsumerWidget {
  final VoidCallback onClear;
  const _SearchHeader({required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
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
          const Text(
            'Melodrift',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF5F1F),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Dark / Light toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: const Color(0xFFFF5F1F),
              size: 22,
            ),
            onPressed: () {
              final notifier = ref.read(themeProvider.notifier);
              notifier.setThemeMode(
                  isDark ? AppThemeMode.light : AppThemeMode.dark);
            },
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onVoiceResult;
  final VoidCallback? onBack;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onVoiceResult,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: onBack,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 16, right: 8),
              splashRadius: 20,
            )
          else ...[
            const SizedBox(width: 16),
            Icon(
              Icons.search,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search for songs, artists, or podcasts',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: Icon(Icons.close,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {
                    controller.clear();
                  },
                  splashRadius: 18,
                );
              }
              return Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.mic_none_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant),
                  splashRadius: 18,
                  onPressed: () async {
                    final result = await showModalBottomSheet<String>(
                      context: ctx,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const VoiceSearchSheet(),
                    );
                    if (result != null && result.isNotEmpty) {
                      onVoiceResult(result);
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default home page: Trending Now + Browse All
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHomePage extends ConsumerWidget {
  final List<String> history;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDeleteHistory;

  const _SearchHomePage({
    required this.history,
    required this.onTap,
    required this.onDeleteHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Recent searches ─────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Recent Searches',
              icon: Icons.history,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final item = history[i];
                  return _HistoryChip(
                    label: item,
                    onTap: () => onTap(item),
                    onDelete: () => onDeleteHistory(item),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Trending Artists (Real Artists — live feed or curated fallback) ──────
        SliverToBoxAdapter(
          child: _TrendingNowSection(onTap: onTap, feedAsync: feedAsync),
        ),

        // ── Trending Songs (JioSaavn 320kbps Lossless Tracks) ───────────────
        SliverToBoxAdapter(
          child: _TrendingSongsSection(feedAsync: feedAsync),
        ),

        // ── Spotify Global Top Hits ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SpotifyTopHitsSearchSection(feedAsync: feedAsync),
        ),

        // ── Browse All (Bento Grid) ──────────────────────────────────────

        feedAsync.when<Widget>(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
                ),
              ),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (feed) {
            final moods = feed.moods;
            if (moods.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverList(
              delegate: SliverChildListDelegate([
                const _SectionTitle(title: 'Browse All'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Builder(
                    builder: (context) {
                      final width = MediaQuery.of(context).size.width;
                      final crossAxisCount = width > 900 ? 5 : (width > 600 ? 4 : 3);
                      final childAspectRatio = width > 600 ? 1.4 : 1.3;

                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: moods.length,
                        itemBuilder: (_, i) {
                          final mood = moods[i];
                          return _BrowseCard(
                            mood: mood,
                            index: i,
                            onTap: () => _openMoodDialog(context, ref, mood),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 180),
              ]),
            );
          },
        ),
      ],
    );
  }

  void _openMoodDialog(BuildContext context, WidgetRef ref, MoodCategory mood) {
    showDialog<void>(
      context: context,
      builder: (_) => _MoodSearchDialog(mood: mood),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trending Now Section — always visible (live feed or curated fallback)
// ─────────────────────────────────────────────────────────────────────────────

// Curated fallback: real globally trending artists with authentic JioSaavn CDN portrait URLs
const List<Map<String, dynamic>> _kFallbackArtists = [
  {
    'name': 'Arijit Singh',
    'image': 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.jpg',
    'glow': Color(0x598B5CF6),
  },
  {
    'name': 'Shreya Ghoshal',
    'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.jpg',
    'glow': Color(0x3DFF69B4),
  },
  {
    'name': 'A R Rahman',
    'image': 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_500x500.jpg',
    'glow': Color(0x3DFFD700),
  },
  {
    'name': 'Anirudh Ravichander',
    'image': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_003_20260121134149_500x500.jpg',
    'glow': Color(0x59FF5F1F),
  },
  {
    'name': 'Diljit Dosanjh',
    'image': 'https://c.saavncdn.com/artists/Diljit_Dosanjh_005_20231025073054_500x500.jpg',
    'glow': Color(0x3D32CD32),
  },
  {
    'name': 'Atif Aslam',
    'image': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'Pritam',
    'image': 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.jpg',
    'glow': Color(0x598B5CF6),
  },
  {
    'name': 'Yo Yo Honey Singh',
    'image': 'https://c.saavncdn.com/artists/Yo_Yo_Honey_Singh_004_20260811095253_500x500.jpg',
    'glow': Color(0x59FF5F1F),
  },
  {
    'name': 'Neha Kakkar',
    'image': 'https://c.saavncdn.com/artists/Neha_Kakkar_007_20241212115832_500x500.jpg',
    'glow': Color(0x3DFF69B4),
  },
  {
    'name': 'Badshah',
    'image': 'https://c.saavncdn.com/artists/Badshah_006_20241118064015_500x500.jpg',
    'glow': Color(0x59FF5F1F),
  },
  {
    'name': 'Sid Sriram',
    'image': 'https://c.saavncdn.com/artists/Sid_Sriram_005_20240425180600_500x500.jpg',
    'glow': Color(0x3D32CD32),
  },
  {
    'name': 'Jubin Nautiyal',
    'image': 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_500x500.jpg',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'Armaan Malik',
    'image': 'https://c.saavncdn.com/artists/Armaan_Malik_006_20260813132832_500x500.jpg',
    'glow': Color(0x598B5CF6),
  },
  {
    'name': 'Sonu Nigam',
    'image': 'https://c.saavncdn.com/artists/Sonu_Nigam_003_20260813182013_500x500.jpg',
    'glow': Color(0x3DFFD700),
  },
  {
    'name': 'Karan Aujla',
    'image': 'https://c.saavncdn.com/artists/Karan_Aujla_004_20260810121947_500x500.jpg',
    'glow': Color(0x59FF5F1F),
  },
  {
    'name': 'AP Dhillon',
    'image': 'https://c.saavncdn.com/artists/AP_Dhillon_004_20251023102150_500x500.jpg',
    'glow': Color(0x3DFFD700),
  },
  {
    'name': 'Sunidhi Chauhan',
    'image': 'https://c.saavncdn.com/artists/Sunidhi_Chauhan_005_20250515061617_500x500.jpg',
    'glow': Color(0x3DFF69B4),
  },
  {
    'name': 'Darshan Raval',
    'image': 'https://c.saavncdn.com/artists/Darshan_Raval_006_20250807060352_500x500.jpg',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'Vishal Mishra',
    'image': 'https://c.saavncdn.com/artists/Vishal_Mishra_005_20251120085316_500x500.jpg',
    'glow': Color(0x598B5CF6),
  },
  {
    'name': 'Akhil Sachdeva',
    'image': 'https://c.saavncdn.com/artists/Akhil_Sachdeva_001_20260811094044_500x500.jpg',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'Taylor Swift',
    'image': 'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_500x500.jpg',
    'glow': Color(0x3DFF69B4),
  },

  {
    'name': 'The Weeknd',
    'image': 'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_500x500.jpg',
    'glow': Color(0x3D8A2BE2),
  },
  {
    'name': 'Dua Lipa',
    'image': 'https://c.saavncdn.com/artists/Dua_Lipa_004_20231120090922_500x500.jpg',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'Ed Sheeran',
    'image': 'https://c.saavncdn.com/artists/Ed_Sheeran_002_20250625073038_500x500.jpg',
    'glow': Color(0x59FF4500),
  },
  {
    'name': 'Billie Eilish',
    'image': 'https://c.saavncdn.com/artists/Billie_Eilish_20190211151539_500x500.jpg',
    'glow': Color(0x3D32CD32),
  },
];




const List<Song> _kFallbackTrendingSongs = [
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

const List<Color> _kGlowColors = [
  Color(0x598B5CF6),
  Color(0x3D00FFFF),
  Color(0x3DFF69B4),
  Color(0x3D32CD32),
  Color(0x3D8A2BE2),
  Color(0x3DFFD700),
];

class _TrendingNowSection extends ConsumerWidget {
  final ValueChanged<String> onTap;
  final AsyncValue<HomeData> feedAsync;

  const _TrendingNowSection({required this.onTap, required this.feedAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Map<String, dynamic>> finalArtists = [];
    final Set<String> seenArtistKeys = {};

    // 1. Guaranteed verified CDN portraits catalog
    for (final a in _kFallbackArtists) {
      final rawName = a['name'] as String;
      final key = getCleanArtistKey(rawName);
      if (key.isNotEmpty && !seenArtistKeys.contains(key)) {
        seenArtistKeys.add(key);
        final canonicalName = getCleanArtistName(rawName);
        final portrait = getArtistPortrait(rawName, a['image'] as String);
        final glow = a['glow'] as Color? ?? _kGlowColors[canonicalName.hashCode.abs() % _kGlowColors.length];
        finalArtists.add({
          'name': canonicalName,
          'image': portrait,
          'glow': glow,
        });
      }
    }

    // 2. Append any live artists from feed if available and verified
    final liveArtists = feedAsync.valueOrNull?.recommendedArtists;
    if (liveArtists != null && liveArtists.isNotEmpty) {
      for (final a in liveArtists) {
        final key = getCleanArtistKey(a.name);
        if (key.isNotEmpty && !seenArtistKeys.contains(key)) {
          final canonicalName = getCleanArtistName(a.name);
          final portrait = getArtistPortrait(a.name, a.artworkUrl);
          if (portrait.isNotEmpty) {
            seenArtistKeys.add(key);
            final glowColor = _kGlowColors[canonicalName.hashCode.abs() % _kGlowColors.length];
            finalArtists.add({
              'name': canonicalName,
              'image': portrait,
              'glow': glowColor,
            });
          }
        }
      }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Trending Artists',
          icon: Icons.local_fire_department_rounded,
          iconColor: Color(0xFFFF5F1F),
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: finalArtists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final artist = finalArtists[i];
              return _TrendingArtistTile(
                name: artist['name'] as String,
                artworkUrl: artist['image'] as String,
                glowColor: artist['glow'] as Color,
                onTap: () => onTap(artist['name'] as String),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}


class _TrendingSongsSection extends ConsumerWidget {
  final AsyncValue<HomeData> feedAsync;

  const _TrendingSongsSection({required this.feedAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveSongs = feedAsync.valueOrNull?.trendingSongs ??
        feedAsync.valueOrNull?.quickPicks ??
        feedAsync.valueOrNull?.charts;
    final songs = (liveSongs != null && liveSongs.isNotEmpty)
        ? liveSongs.take(8).toList()
        : _kFallbackTrendingSongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle(
                title: 'Trending Songs',
                icon: Icons.trending_up_rounded,
                iconColor: Color(0xFF8B5CF6),
              ),
              if (songs.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    ref.read(playerStateProvider.notifier).playQueue(songs);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFFFF5F1F)),
                  label: const Text(
                    'Play All',
                    style: TextStyle(color: Color(0xFFFF5F1F), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongCard(
              song: song,
              queue: songs,
              queueIndex: index,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

const List<Song> _kFallbackSpotifySongs = [
  Song(
    id: 'spotify_espresso',
    title: 'Espresso',
    artist: 'Sabrina Carpenter',
    album: 'Short n\' Sweet',
    duration: Duration(minutes: 2, seconds: 55),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273659d0e7e174092b67f1396a9',
    videoId: 'espresso',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_birds_of_a_feather',
    title: 'BIRDS OF A FEATHER',
    artist: 'Billie Eilish',
    album: 'HIT ME HARD AND SOFT',
    duration: Duration(minutes: 3, seconds: 30),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b27371d62ea7ea8a5be92d3c1f62',
    videoId: 'birds_of_a_feather',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_greedy',
    title: 'greedy',
    artist: 'Tate McRae',
    album: 'THINK LATER',
    duration: Duration(minutes: 2, seconds: 11),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b27322fd80276f3c15d796db630e',
    videoId: 'greedy',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_cruel_summer',
    title: 'Cruel Summer',
    artist: 'Taylor Swift',
    album: 'Lover',
    duration: Duration(minutes: 2, seconds: 58),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273e787cffec20aa2a396a61647',
    videoId: 'cruel_summer',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_blinding_lights',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    album: 'After Hours',
    duration: Duration(minutes: 3, seconds: 20),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
    videoId: 'blinding_lights',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_levitating',
    title: 'Levitating',
    artist: 'Dua Lipa',
    album: 'Future Nostalgia',
    duration: Duration(minutes: 3, seconds: 23),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273bd26ede1ae69327010d49946',
    videoId: 'levitating',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_shape_of_you',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    album: 'Divide',
    duration: Duration(minutes: 3, seconds: 53),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273ba5db46f4b838ef6027e6f96',
    videoId: 'shape_of_you',
    source: 'Spotify',
  ),
  Song(
    id: 'spotify_starboy',
    title: 'Starboy',
    artist: 'The Weeknd',
    album: 'Starboy',
    duration: Duration(minutes: 3, seconds: 50),
    artworkUrl: 'https://i.scdn.co/image/ab67616d0000b2734718e2b124f79258be7bc452',
    videoId: 'starboy',
    source: 'Spotify',
  ),
];


class _SpotifyTopHitsSearchSection extends ConsumerWidget {
  final AsyncValue<HomeData> feedAsync;

  const _SpotifyTopHitsSearchSection({required this.feedAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveSongs = feedAsync.valueOrNull?.spotifyTopHits;
    final songs = (liveSongs != null && liveSongs.isNotEmpty)
        ? liveSongs.take(6).toList()
        : _kFallbackSpotifySongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle(
                title: 'Melodrift Global Top Hits',
                icon: Icons.graphic_eq_rounded,
                iconColor: Color(0xFF1DB954),
              ),

              if (songs.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    ref.read(playerStateProvider.notifier).playQueue(songs);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFF1DB954)),
                  label: const Text(
                    'Play All',
                    style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongCard(
              song: song,
              queue: songs,
              queueIndex: index,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;

  const _SectionTitle({required this.title, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 18, color: iconColor ?? theme.colorScheme.onSurface),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trending artist circle tile (Stateful with touch scale down feedback)
// ─────────────────────────────────────────────────────────────────────────────

class _TrendingArtistTile extends StatefulWidget {
  final String name;
  final String artworkUrl;
  final Color? glowColor;
  final VoidCallback onTap;

  const _TrendingArtistTile({
    required this.name,
    required this.artworkUrl,
    required this.onTap,
    this.glowColor,
  });

  @override
  State<_TrendingArtistTile> createState() => _TrendingArtistTileState();
}

class _TrendingArtistTileState extends State<_TrendingArtistTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor ?? theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Builder(
                  builder: (context) {
                    var imgUrl = getArtistPortrait(widget.name, widget.artworkUrl);
                    if (imgUrl.isEmpty) {
                      imgUrl = widget.artworkUrl;
                    }
                    imgUrl = imgUrl
                        .replaceAll('150x150', '500x500')
                        .replaceAll('50x50', '500x500');

                    if (imgUrl.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ArtistFallback(name: widget.name),
                      );
                    }
                    return _ArtistFallback(name: widget.name);
                  },
                ),
              ),

            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 90,
              child: Text(
                widget.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistFallback extends StatelessWidget {
  final String name;
  const _ArtistFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFF5F1F),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Browse All Category Design system matching code.html
// ─────────────────────────────────────────────────────────────────────────────

class _MoodDesignPreset {
  final String imageUrl;
  final List<Color> gradientColors;
  final Color glowColor;

  const _MoodDesignPreset({
    required this.imageUrl,
    required this.gradientColors,
    required this.glowColor,
  });
}

final Map<String, _MoodDesignPreset> _moodDesignPresets = {
  'trending': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    gradientColors: [Color(0x66FF5F1F), Colors.black],
    glowColor: Color(0xFFFF5F1F),
  ),
  'romance': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=600&q=80',
    gradientColors: [Color(0x66E91E63), Colors.black],
    glowColor: Color(0xFFE91E63),
  ),
  'party': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&q=80',
    gradientColors: [Color(0x669C27B0), Colors.black],
    glowColor: Color(0xFFAB47BC),
  ),
  'punjabi': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=600&q=80',
    gradientColors: [Color(0x66FF9800), Colors.black],
    glowColor: Color(0xFFFFB300),
  ),
  'chill': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=600&q=80',
    gradientColors: [Color(0x66006064), Colors.black],
    glowColor: Color(0xFF00BCD4),
  ),
  'workout': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
    gradientColors: [Color(0x66D32F2F), Colors.black],
    glowColor: Color(0xFFFF5252),
  ),
  'retro': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&q=80',
    gradientColors: [Color(0x66BF360C), Colors.black],
    glowColor: Color(0xFFFF7043),
  ),
  'edm': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    gradientColors: [Color(0x6600BCD4), Colors.black],
    glowColor: Color(0xFF18FFFF),
  ),
  'acoustic': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=600&q=80',
    gradientColors: [Color(0x664E342E), Colors.black],
    glowColor: Color(0xFF8D6E63),
  ),
  'hiphop': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
    gradientColors: [Color(0x66FF6F00), Colors.black],
    glowColor: Color(0xFFFF9800),
  ),
  'hip_hop': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
    gradientColors: [Color(0x66FF6F00), Colors.black],
    glowColor: Color(0xFFFF9800),
  ),
  'bollywood': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    gradientColors: [Color(0x66C2185B), Colors.black],
    glowColor: Color(0xFFFF4081),
  ),
  'devotional': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1609743522653-52354461cf27?w=600&q=80',
    gradientColors: [Color(0x66E65100), Colors.black],
    glowColor: Color(0xFFFFB300),
  ),
  'focus': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=600&q=80',
    gradientColors: [Color(0x66004D40), Colors.black],
    glowColor: Color(0xFF00E676),
  ),
  'rock': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1464375117522-1311d6a5b81f?w=600&q=80',
    gradientColors: [Color(0x66B71C1C), Colors.black],
    glowColor: Color(0xFFF44336),
  ),
  'sufi': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    gradientColors: [Color(0x66311B92), Colors.black],
    glowColor: Color(0xFF7C4DFF),
  ),
  'kpop': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1516873240891-4bf014598ab4?w=600&q=80',
    gradientColors: [Color(0x66880E4F), Colors.black],
    glowColor: Color(0xFFFF4081),
  ),
  'pop': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    gradientColors: [Color(0x669C27B0), Colors.black],
    glowColor: Color(0xFFE91E63),
  ),
  'indie': const _MoodDesignPreset(
    imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    gradientColors: [Color(0x660D47A1), Colors.black],
    glowColor: Color(0xFF2196F3),
  ),
};

_MoodDesignPreset _getPresetForMood(MoodCategory mood, int index) {
  final id = mood.id.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (_moodDesignPresets.containsKey(id)) {
    return _moodDesignPresets[id]!;
  }

  final title = mood.title.toLowerCase();

  for (final entry in _moodDesignPresets.entries) {
    if (title.contains(entry.key) || entry.key.contains(title)) {
      return entry.value;
    }
  }

  // Relax/Chill/Sleep/Acoustic
  if (title.contains('relax') ||
      title.contains('chill') ||
      title.contains('sleep') ||
      title.contains('acoustic') ||
      title.contains('rainy')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=600&q=80',
      gradientColors: [Color(0x59003057), Colors.black],
      glowColor: Color(0xFF00BCD4),
    );
  }

  // Workout/Energize/Motivation/Gaming
  if (title.contains('workout') ||
      title.contains('energiz') ||
      title.contains('motivation') ||
      title.contains('gaming') ||
      title.contains('party')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
      gradientColors: [Color(0x597A0016), Colors.black],
      glowColor: Color(0xFFFF5F1F),
    );
  }

  // Romantic/Happy/Feel Good/Morning
  if (title.contains('romance') ||
      title.contains('love') ||
      title.contains('happy') ||
      title.contains('feel') ||
      title.contains('morning')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=600&q=80',
      gradientColors: [Color(0x595C003E), Colors.black],
      glowColor: Color(0xFFE91E63),
    );
  }

  // Classical/Jazz/Soul/Lofi/90s
  if (title.contains('classical') ||
      title.contains('jazz') ||
      title.contains('soul') ||
      title.contains('retro') ||
      title.contains('lofi') ||
      title.contains('90s')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&q=80',
      gradientColors: [Color(0x594A2C00), Colors.black],
      glowColor: Color(0xFFFFB300),
    );
  }

  // Bollywood/Indian/Punjabi/Ghazal/Sufi
  if (title.contains('bollywood') ||
      title.contains('indian') ||
      title.contains('punjabi') ||
      title.contains('ghazal') ||
      title.contains('sufi') ||
      title.contains('devotional')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      gradientColors: [Color(0x595F2300), Colors.black],
      glowColor: Color(0xFFFF5F1F),
    );
  }

  // Fallbacks
  const List<List<Color>> fallbackGradients = [
    [Color(0x59330E62), Colors.black],
    [Color(0x591B5E20), Colors.black],
    [Color(0x5901579B), Colors.black],
    [Color(0x593E2723), Colors.black],
    [Color(0x59311B92), Colors.black],
    [Color(0x59004D40), Colors.black],
  ];
  const List<Color> fallbackGlows = [
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
    Color(0xFF03A9F4),
    Color(0xFF8D6E63),
    Color(0xFF673AB7),
    Color(0xFF009688),
  ];
  const List<String> fallbackImages = [
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&q=80',
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
  ];

  return _MoodDesignPreset(
    imageUrl: fallbackImages[index % fallbackImages.length],
    gradientColors: fallbackGradients[index % fallbackGradients.length],
    glowColor: fallbackGlows[index % fallbackGlows.length],
  );
}

class _BrowseCard extends StatefulWidget {
  final MoodCategory mood;
  final int index;
  final VoidCallback onTap;

  const _BrowseCard({
    required this.mood,
    required this.index,
    required this.onTap,
  });

  @override
  State<_BrowseCard> createState() => _BrowseCardState();
}

class _BrowseCardState extends State<_BrowseCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final preset = _getPresetForMood(widget.mood, widget.index);

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // rounded-artwork
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: preset.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background Image layer (mix-blend-overlay equivalent: opacity 0.5)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.5,
                  child: CachedNetworkImage(
                    imageUrl: preset.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Soft black gradient overlay to ensure text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
              ),
              // Blur-2xl circle blob at the bottom right
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        preset.glowColor.withOpacity(0.25),
                        preset.glowColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Text label
              Positioned(
                left: 10,
                bottom: 10,
                child: Text(
                  widget.mood.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion / history list
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final List<String> history;
  final int highlightedIndex;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDeleteHistory;

  const _SuggestionsList({
    required this.suggestions,
    required this.history,
    required this.highlightedIndex,
    required this.onTap,
    required this.onDeleteHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = suggestions.isNotEmpty ? suggestions : history;
    final isHistory = suggestions.isEmpty;

    if (items.isEmpty) {
      return Center(
        child: Text('Type to search…',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 180),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final isHighlighted = i == highlightedIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
            onTap(item);
          },
          child: Container(
            color: isHighlighted ? theme.colorScheme.primary.withOpacity(0.12) : null,
            child: ListTile(
              leading: Icon(
                isHistory ? Icons.history : Icons.search,
                size: 20,
                color: isHighlighted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  color: isHighlighted ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isHistory
                  ? IconButton(
                      icon: Icon(Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () => onDeleteHistory(item),
                      splashRadius: 16,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History chip
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood song dialog (reused from mood_card.dart logic)
// ─────────────────────────────────────────────────────────────────────────────

class _MoodSearchDialog extends ConsumerStatefulWidget {
  final MoodCategory mood;
  const _MoodSearchDialog({required this.mood});

  @override
  ConsumerState<_MoodSearchDialog> createState() => _MoodSearchDialogState();
}

class _MoodSearchDialogState extends ConsumerState<_MoodSearchDialog> {
  late Future<List<Song>> _futureSongs;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(musicRepositoryProvider);
    _futureSongs = repo.getMoodCategorySongs(widget.mood.id, widget.mood.title, limit: 100);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentSongId = ref.watch(playerStateProvider.select((s) => s.currentSong?.id));
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      backgroundColor: isDark
          ? const Color(0xFF16161E)
          : theme.colorScheme.surfaceContainerLowest,
      elevation: 24,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 480,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5F1F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFFF5F1F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mood.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF5F1F),
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Curated Songs & Hits',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Song>>(
                future: _futureSongs,
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return const Center(child: Text('No songs found'));
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.read(playerStateProvider.notifier).playQueue(songs);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5F1F),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(
                              'Play All (${songs.length} Tracks)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: songs.length,
                          itemBuilder: (_, i) {
                            final song = songs[i];
                            final isCurrent = currentSongId == song.id ||
                                (currentSongId != null &&
                                    (currentSongId.endsWith(song.id) || song.id.endsWith(currentSongId)));
                            final isCurrentlyPlaying = isCurrent && isPlaying;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFFF5F1F).withOpacity(0.12)
                                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFFFF5F1F).withOpacity(0.4)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    ref.read(playerStateProvider.notifier).playQueue(songs, initialIndex: i);
                                    Navigator.of(context).pop();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: song.artworkUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: song.artworkUrl,
                                                      width: 46,
                                                      height: 46,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => Container(
                                                        width: 46,
                                                        height: 46,
                                                        color: theme.colorScheme.surfaceContainerHighest,
                                                        child: const Icon(Icons.music_note, size: 20),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 46,
                                                      height: 46,
                                                      color: theme.colorScheme.surfaceContainerHighest,
                                                      child: const Icon(Icons.music_note, size: 20),
                                                    ),
                                            ),
                                            if (isCurrentlyPlaying)
                                              Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.equalizer_rounded,
                                                  color: Color(0xFFFF5F1F),
                                                  size: 24,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                  color: isCurrent ? const Color(0xFFFF5F1F) : theme.colorScheme.onSurface,
                                                  fontSize: 13.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                song.artist,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                  fontSize: 11.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (song.duration > Duration.zero) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDuration(song.duration),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withOpacity(0.45),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        IconButton(
                                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                          splashRadius: 20,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => showSongOptionsMenu(context, ref, song),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
