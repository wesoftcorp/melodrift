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
import '../../domain/entities/home_data.dart';
import 'home_screen.dart';
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
          // Logo
          Text(
            'Melodrift',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFF5F1F),
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

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onVoiceResult,
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
          const SizedBox(width: 16),
          Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
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
    final AsyncValue<HomeData> feedAsync = ref.watch(homeFeedProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Recent searches ─────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          SliverToBoxAdapter(
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

        // ── Trending Now ────────────────────────────────────────────────
        feedAsync.when<Widget>(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (feed) {
            final artists = feed.recommendedArtists;
            if (artists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    title: 'Trending Now',
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF5F1F),
                  ),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (_, i) {
                        final artist = artists[i];
                        return _TrendingArtistTile(
                          name: artist.name,
                          artworkUrl: artist.artworkUrl,
                          onTap: () => onTap(artist.name),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),

        // ── Browse All ──────────────────────────────────────────────────
        feedAsync.when<Widget>(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (feed) {
            final moods = feed.moods;
            if (moods.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverList(
              delegate: SliverChildListDelegate([
                _SectionTitle(title: 'Browse All'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.45,
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
// Trending artist circle tile
// ─────────────────────────────────────────────────────────────────────────────

class _TrendingArtistTile extends StatelessWidget {
  final String name;
  final String artworkUrl;
  final VoidCallback onTap;

  const _TrendingArtistTile({
    required this.name,
    required this.artworkUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF5F1F).withOpacity(0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5F1F).withOpacity(0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: artworkUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: artworkUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _ArtistFallback(name: name),
                    )
                  : _ArtistFallback(name: name),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 76,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFF5F1F),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Browse All card (2-col grid with gradient + artwork)
// ─────────────────────────────────────────────────────────────────────────────

class _BrowseCard extends StatelessWidget {
  final MoodCategory mood;
  final int index;
  final VoidCallback onTap;

  const _BrowseCard({
    required this.mood,
    required this.index,
    required this.onTap,
  });

  // Curated dark gradient palettes per card index
  static const List<List<Color>> _palettes = [
    [Color(0xFF6B1A2A), Color(0xFF2A0A10)], // Deep crimson
    [Color(0xFF0D2B4A), Color(0xFF060F1A)], // Deep navy
    [Color(0xFF1A3A1A), Color(0xFF080F08)], // Deep forest
    [Color(0xFF2A1A4A), Color(0xFF0D0818)], // Deep purple
    [Color(0xFF3A2A0A), Color(0xFF150F05)], // Deep amber
    [Color(0xFF0A2A3A), Color(0xFF051018)], // Deep teal
    [Color(0xFF3A0A2A), Color(0xFF150510)], // Deep magenta
    [Color(0xFF1A2A0A), Color(0xFF0A1005)], // Deep olive
    [Color(0xFF0A1A3A), Color(0xFF050A18)], // Deep blue
    [Color(0xFF3A1A0A), Color(0xFF180805)], // Deep burnt orange
    [Color(0xFF1A0A3A), Color(0xFF0A0518)], // Deep indigo
    [Color(0xFF0A3A1A), Color(0xFF05180A)], // Deep emerald
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[index % _palettes.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle blobs for visual texture
            Positioned(
              right: -16,
              bottom: -16,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: -24,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            // Genre label
            Positioned(
              left: 14,
              bottom: 14,
              child: Text(
                mood.title,
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
