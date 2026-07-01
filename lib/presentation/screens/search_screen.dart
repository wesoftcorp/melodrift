import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/entities/mood_category.dart';
import '../../domain/entities/song.dart';
import '../widgets/search_results_view.dart';
import '../widgets/voice_search_sheet.dart';
import '../../core/theme/theme_provider.dart';
import 'home_screen.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/artist.dart';
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
  String _submittedQuery = '';
  List<String> _suggestions = [];
  List<String> _history = [];
  Timer? _debounce;
  bool _isFocused = false;

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
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (_focusNode.hasFocus && _submittedQuery.isNotEmpty) {
      setState(() => _submittedQuery = '');
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final repo = ref.read(musicRepositoryProvider);
      final suggestions = await repo.getSearchSuggestions(query);
      if (mounted) setState(() => _suggestions = suggestions);
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
    setState(() => _submittedQuery = cleanQuery);
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.addSearchQuery(cleanQuery);
    await _loadHistory();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _submittedQuery = '';
      _suggestions = [];
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
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
                onSubmitted: _runSearch,
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
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    // 1. Results after submit
    if (_submittedQuery.isNotEmpty && !_isFocused) {
      return SearchResultsView(query: _submittedQuery);
    }

    // 2. Live suggestions while typing
    if (_isFocused && _controller.text.trim().isNotEmpty) {
      return _SuggestionsList(
        suggestions: _suggestions,
        history: _history,
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
          Image.asset(
            'assets/images/melodrift.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
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

        // ── Trending Now (Real Artists — live feed or curated fallback) ──────
        SliverToBoxAdapter(
          child: _TrendingNowSection(onTap: onTap, feedAsync: feedAsync),
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
                      final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
                      final childAspectRatio = width > 600 ? 1.6 : 1.8;

                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
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
                const SizedBox(height: 120),
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

// Curated fallback: real globally trending artists with stable image URLs
const List<Map<String, dynamic>> _kFallbackArtists = [
  {
    'name': 'Arijit Singh',
    'image': 'https://c.saavncdn.com/artists/Arijit_Singh_004_20230808082952_500x500.jpg',
    'glow': Color(0x59FF4500),
  },
  {
    'name': 'Taylor Swift',
    'image': 'https://i.scdn.co/image/ab6761610000e5eb5a00969a4698c3132a15fbb0',
    'glow': Color(0x3DFF69B4),
  },
  {
    'name': 'The Weeknd',
    'image': 'https://i.scdn.co/image/ab6761610000e5eb214f3cf1cbe7139c1e26ffbb',
    'glow': Color(0x3D8A2BE2),
  },
  {
    'name': 'Dua Lipa',
    'image': 'https://i.scdn.co/image/ab6761610000e5eb3f2cca81f1fa3b2a0d3c38b3',
    'glow': Color(0x3D00FFFF),
  },
  {
    'name': 'A.R. Rahman',
    'image': 'https://c.saavncdn.com/artists/A_R_Rahman_001_20230808082754_500x500.jpg',
    'glow': Color(0x3DFFD700),
  },
  {
    'name': 'Bad Bunny',
    'image': 'https://i.scdn.co/image/ab6761610000e5eb5be01f90a5571c9b5ca5ad6d',
    'glow': Color(0x3D32CD32),
  },
  {
    'name': 'Shreya Ghoshal',
    'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_002_20230808082952_500x500.jpg',
    'glow': Color(0x3DFF69B4),
  },
  {
    'name': 'Ed Sheeran',
    'image': 'https://i.scdn.co/image/ab6761610000e5eb3bcef85e105dfc42399ef0ba',
    'glow': Color(0x59FF4500),
  },
];

const List<Color> _kGlowColors = [
  Color(0x59FF4500),
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
    // Use live artists from feed if available, else show curated fallback
    final liveArtists = feedAsync.valueOrNull?.recommendedArtists;
    final bool useLive = liveArtists != null && liveArtists.isNotEmpty;
    final artists = liveArtists ?? <Artist>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Trending Now',
          icon: Icons.local_fire_department_rounded,
          iconColor: Color(0xFFFF4500),
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: useLive ? artists.length : _kFallbackArtists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              if (useLive) {
                final artist = artists[i];
                final glowColor = _kGlowColors[artist.name.hashCode.abs() % _kGlowColors.length];
                return _TrendingArtistTile(
                  name: artist.name,
                  artworkUrl: artist.artworkUrl,
                  glowColor: glowColor,
                  onTap: () => onTap(artist.name),
                );
              } else {
                final entry = _kFallbackArtists[i];
                return _TrendingArtistTile(
                  name: entry['name'] as String,
                  artworkUrl: entry['image'] as String,
                  glowColor: entry['glow'] as Color,
                  onTap: () => onTap(entry['name'] as String),
                );
              }
            },
          ),
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
                child: widget.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.artworkUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ArtistFallback(name: widget.name),
                      )
                    : _ArtistFallback(name: widget.name),
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
  'pop': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD8bVtvbm45O2pOf0qmGkMzzoFZfp4tJCu5pt8kX7N3Ebn7D8EyJMbUn6-Hr4uL0ZVb9jolKmSSvtVj_WVn5Pq3T20sNIkdGClg39fqee8DS_QOC5Wij_GnH4oC3aSX3lTMQfmxOvcM9tBWk8RQnga8sz9rwjIGCWOttLr_bHXi9v7roQEH5dM-hvIMI76dKhe3gfVu6SafaSMhNWaA99jaXEiQ4HYKKKhLWBrDxkFYEYBaQhi_mcKCclf3mcnzrK8TERgOB4o6oEc',
    gradientColors: [Color(0x669C27B0), Colors.black],
    glowColor: Color(0xFFE91E63),
  ),
  'indie': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD8k2GHMYYX2Bki8U27EPTeMtvg766ilWLyvX6pl1RKgI2P9wy_uzC5XAj0A5OfQ7REqixgCgDoAAcyaAY-bCqNHRs_TLMJqfwt2Xv3cuJ06QFc8b_jPEDcskTo4331op5eArXc9JKZb_VDYlz5CZQOuudbkOFXj38PTxA6qcxxHYle08qN3SHcAEKxyTCkLEhxhBRk8US_VdwMTfgtYsTiMlai8wT1e9ZPoDW7gLlWjI6caMJaQpQZcQ5d-ALLbRmEgNiO7WcuQPA',
    gradientColors: [Color(0x660D47A1), Colors.black],
    glowColor: Color(0xFF2196F3),
  ),
  'rock': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC7HXa1jGDbTONlmCMs8N4JkMaCVjEb0XohXbm3LtKJIBE_HHnYkZcSMWtbq4yxEnp7L0SNbRTmNk06093OjIVCxewnlyWFNO2HFwLlsfD0BXboPMgNio2J2IOvWrOXT9BXaUB-de7x2vwYLoSKjERY6A3ek161VH105SmKbdePWFceRWYfXPef5Lb_PPdlOYftRg6H2XFYQRJNN6dq8UZSCRfYdXOxYo7gX86rHULKjSDFH157nUaJ7CWBf-Rj5HpU38A51XjLjSA',
    gradientColors: [Color(0x66B71C1C), Colors.black],
    glowColor: Color(0xFFF44336),
  ),
  'edm': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB_uKXoOWvCq-rB0khJy7uYi9xI9pzd9gTJqzD_lMdBVOzx4tAbF8Q-lHBK9SUUewjVWO93U2AxYJJ4XdxLD21wI6AO3NB42rUrrlJbcUtqoKadl8HhKFKTy_AU4_WDDm7hjgkqkUN8w52z6xHURcNTii_JwWoQc3rML4CNgXHk_oZkkoguTZrBTruUbgr-i4KKKXA2LYG06OaOz1PlYMj95arZc-6wGMXCx-dEuoVvq6s0U0aoqrBlqUAOrJTLzMFWEP_hK3SP5HU',
    gradientColors: [Color(0x66006064), Colors.black],
    glowColor: Color(0xFF00BCD4),
  ),
  'hip_hop': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDm0OOyJVQRKQu-qMDMl5GkQ7h7PZ036BjweFfZWQ3ZveJ6uMjqSDCq2BXHi7sjPWqfIhHaSCfzfAIgfk0LOHvY6KjKPi5NgmmEQfY5jmDW_QKV6eeXdsMgAMb8izFkV-duTOl12kzlVa-6gAOK6_Qvx4OOr3TevKiRcDwrKr6tZNmKPzyW1fukiuYLd3tuU38PR5s43E8agZ0wZBrdK-5xYQeQfu7N9AYOSX7BD9EInFsBWrBEFIdtoE56oEAFFLQaWSnoA6eMNYM',
    gradientColors: [Color(0x66FF6F00), Colors.black],
    glowColor: Color(0xFFFF9800),
  ),
  'focus': const _MoodDesignPreset(
    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDKYYCBN79OVf1RPNktmM_s25AoQpiXY_pC2mSCfWiyqEd7U9OvGlFaRWdTwyM6792D1Es7u0o1tV2bmPwnxXivI6cvjDyNaguOiJX5IM3rNUFepPb9DneJjWO8abeMhSJ-edk00I06cfUQ27B-LbITm0JEDJImzDitay8O9i-mSZBrWLToiwjecNUKpwCBiYfjsoV_oS4Pd6uY9RmakaCFFusWlQpKZYu-uYnHEO4LrX4rFBQwVyWkeO_EEdq2IiETp_DhOsYDHPg',
    gradientColors: [Color(0x66004D40), Colors.black],
    glowColor: Color(0xFF00E676),
  ),
};

_MoodDesignPreset _getPresetForMood(MoodCategory mood, int index) {
  final id = mood.id.toLowerCase();
  if (_moodDesignPresets.containsKey(id)) {
    return _moodDesignPresets[id]!;
  }

  final title = mood.title.toLowerCase();

  // Relax/Chill/Sleep/Acoustic
  if (title.contains('relax') ||
      title.contains('chill') ||
      title.contains('sleep') ||
      title.contains('acoustic') ||
      title.contains('rainy')) {
    return const _MoodDesignPreset(
      imageUrl: 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=400&q=80',
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
      imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=400&q=80',
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
      imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&q=80',
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
      imageUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=400&q=80',
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
      imageUrl: 'https://images.unsplash.com/photo-1583258292688-d0213df4a3a8?w=400&q=80',
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
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80',
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80',
    'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=400&q=80',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80',
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
                left: 14,
                bottom: 14,
                child: Text(
                  widget.mood.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDeleteHistory;

  const _SuggestionsList({
    required this.suggestions,
    required this.history,
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
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          leading: Icon(
            isHistory ? Icons.history : Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(item,
              style:
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
          trailing: isHistory
              ? IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => onDeleteHistory(item),
                  splashRadius: 16,
                )
              : null,
          onTap: () => onTap(item),
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
    _futureSongs = repo.searchSongs('${widget.mood.title} music');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surfaceContainerLowest,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
          maxWidth: 460,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.mood.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF5F1F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(playerStateProvider.notifier).playQueue(songs);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5F1F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play All'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: songs.length,
                          itemBuilder: (_, i) {
                            final song = songs[i];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: song.artworkUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: song.artworkUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.music_note),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: const Icon(Icons.music_note),
                                      ),
                              ),
                              title: Text(
                                song.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFFFF5F1F),
                              ),
                              onTap: () {
                                ref
                                    .read(playerStateProvider.notifier)
                                    .playSong(song);
                                Navigator.of(context).pop();
                              },
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
