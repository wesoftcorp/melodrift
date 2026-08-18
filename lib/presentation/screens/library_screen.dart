import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../widgets/downloads_list.dart';
import '../widgets/playlists_list.dart';
import '../widgets/history_list.dart';
import '../providers/player_notifier.dart';
import '../widgets/layout/mini_player.dart';
import '../providers/auth_provider.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/innertube_service.dart';
import '../../core/services/music_track.dart';

@RoutePage()


class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 600;
    final int crossAxisCount = isWide ? 4 : 2;
    final double gridWidth = screenWidth - 32; // 16px horizontal margins
    final double cardWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount; // 16px grid spacing
    const double targetHeight = 120.0; // target height matching code.html
    final double childAspectRatio = cardWidth / targetHeight;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom Header ─────────────────────────────────────────────
            const _LibraryHeader(),

            // ── Main scroll area ──────────────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 20),
                    child: Text(
                      'Your Library',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Categories Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _LibraryCategoryCard(
                        title: 'Downloads',
                        icon: Icons.download_done_rounded,
                        glowColor: const Color(0xFF64C8FF), // Blue glow
                        onTap: () => _openSubPage('Downloads', const DownloadsList()),
                      ),
                      _LibraryCategoryCard(
                        title: 'Playlists',
                        icon: Icons.queue_music_rounded,
                        glowColor: const Color(0xFFFF4500), // Orange glow
                        onTap: () => _openSubPage(
                          'Playlists',
                          const PlaylistsList(),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.link_rounded),
                              tooltip: 'Import Playlist from URL',
                              onPressed: _showImportPlaylistDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_box_outlined),
                              onPressed: _showCreatePlaylistDialog,
                            ),
                          ],
                        ),
                      ),

                      _LibraryCategoryCard(
                        title: 'History',
                        icon: Icons.history_rounded,
                        glowColor: const Color(0xFFFFD700), // Gold glow
                        onTap: () => _openSubPage('Listening History', const HistoryList()),
                      ),
                      _LibraryCategoryCard(
                        title: 'New Playlist',
                        icon: Icons.add_rounded,
                        glowColor: const Color(0xFF32CD32), // Green glow
                        onTap: _showCreatePlaylistDialog,
                      ),
                    ],
                  ),

                  // ── YouTube Music Synced Section ─────────────────────────────
                  if (ref.watch(youtubeAuthProvider) != null) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => _openYoutubeLikedSongs(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade900.withOpacity(0.4),
                              Colors.red.shade600.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'YouTube Liked Songs',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Synced via InnerTube account',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),


                  // Recently Added header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recently Added',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List of Recently Added (curated fallback or real)
                  const _RecentlyAddedList(),

                  const SizedBox(height: 180),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openYoutubeLikedSongs(BuildContext context) {
    _openSubPage(
      'YouTube Liked Songs',
      const _YoutubeLikedSongsView(),
    );
  }

  void _openSubPage(String title, Widget body, {List<Widget>? actions}) {
    context.router.pushWidget(
      _SubPageScaffold(
        title: title,

        body: body,
        actions: actions,
      ),
    );
  }


  void _showImportPlaylistDialog() {
    final urlController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Playlist from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste any YouTube or YouTube Music playlist link:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'https://www.youtube.com/playlist?list=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Importing playlist tracks...')),
              );

              final innerTube = getIt<InnerTubeService>();
              final tracks = await innerTube.fetchPlaylistFromUrl(url);

              if (tracks.isNotEmpty && mounted) {
                final playlistRepo = ref.read(playlistRepositoryProvider);
                final playlistId = 'imported_${DateTime.now().millisecondsSinceEpoch}';
                final playlist = Playlist(
                  id: playlistId,
                  title: 'Imported Playlist (${tracks.length} tracks)',
                  description: 'Imported via URL',
                  artworkUrl: tracks.first.artworkUrl,
                  trackCount: tracks.length,
                  songs: const [],
                  isYouTube: false,
                  isLocal: true,
                );

                await playlistRepo.createPlaylist(playlist);

                for (final track in tracks) {
                  final song = Song(
                    id: track.id,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: track.duration,
                    artworkUrl: track.artworkUrl,
                    videoId: track.id,
                    source: 'YouTube Music',
                  );
                  await playlistRepo.addSongToPlaylist(playlist.id, song);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully imported "${playlist.title}"!')),
                  );
                  setState(() {});
                }
              }
 else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to import playlist or no tracks found.')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {

    final titleController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter playlist title',
            prefixIcon: Icon(Icons.playlist_add),
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              // Close dialog immediately — avoid stale context issues
              Navigator.pop(dialogContext);

              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final playlist = Playlist(
                id: id,
                title: title,
                description: 'Custom local playlist',
                artworkUrl: '',
                trackCount: 0,
                songs: const [],
                isYouTube: false,
                isLocal: true,
              );
              await ref.read(playlistRepositoryProvider).createPlaylist(playlist);

              // Show confirmation
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playlist "$title" created'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader();

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
              color: Color(0xFFFF4500),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Dark / Light toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: const Color(0xFFFF4500),
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
// Category Grid Card (Tactile Scaling)
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryCategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color glowColor;
  final VoidCallback onTap;

  const _LibraryCategoryCard({
    required this.title,
    required this.icon,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_LibraryCategoryCard> createState() => _LibraryCategoryCardState();
}

class _LibraryCategoryCardState extends State<_LibraryCategoryCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(isDark ? 0.15 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.glowColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.glowColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
// Recently Added List & Items (Live + Fallback)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentlyAddedList extends ConsumerWidget {
  const _RecentlyAddedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyRepo = ref.watch(historyRepositoryProvider);

    return FutureBuilder<List<Song>>(
      future: historyRepo.getListeningHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final songs = snapshot.data ?? [];

        // If history is empty, show curated fallback placeholders from code.html
        if (songs.isEmpty) {
          return const Column(
            children: [
              _CuratedHistoryItem(
                title: 'Midnight Echoes',
                subtitle: 'Album • The Synthetics',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDmYrssaDV0PZUKOM-chgp8nSZGZkRQsUQ8JDZA950gdOcpk6mFu6t8xAHlJxfRwpC3tRv-BEXG08VIBzIz1BoKIJmDUjAsVkFFK3emXovIrEUFG7JJBnxlN_FvKXCYC_2CPr-c5WFvtq9J7NhkydMlQuA736bkmHUOuyJ8A8MnbREuexC8WFmySqEPwv2dr7AoyRwZLWVbWLYQxtjZXT2fChf1dbJTRx1gtPJG-OG2YKVjnzt09xiOkFQg3E3hBmW6lNTK2TSgmoA',
                isArtist: false,
                glowColor: Color(0x3DFFB3B5),
              ),
              _CuratedHistoryItem(
                title: 'Structure & Void',
                subtitle: 'Playlist • 42 tracks',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBIMDwyfXzseMzgTJ7B_z8ARi_5eQNGCi57gWmHfFCWeYmvVIpOK-Nie0JnWSaduI29hxi-wE_3vz-riT_9HOVFTynRfKnyjSbyCd4e0YOut_XZrAyldRfqPij6SWBMfXv2bUlNjsyB1WVwnUupQTbD6VF_eaAKmPTWMjWMh5XJklIXN3nTs5kwPAStk73jnyRAb59E1d4QBZ6zQnTLtcdpx2IkmrFXd_AaSzDOwhp97ynuoKqJ_uUssD7cUMbmMNH0CXjDHZ0OGYU',
                isArtist: false,
                glowColor: Color(0x3D64C8FF),
              ),
              _CuratedHistoryItem(
                title: 'Lumina',
                subtitle: 'Artist',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCovvhHTPnRbAH7NJC4M1VC9urVDaMj4ysnw9BAWwKhTY5qQlhCa_F2tGRzP59l_UvOWG5_PF0CYQyteQTU6EZWy0mPjcW__aj8kFN_VLnQ_XIS2HutLALl8d3qCsBlWkynCIuPFtlqWTSn002r_t0l8q_iwJjVGCd-Plr0vL6pO8rH6e4mwD9S3MPivD1Bqf_VnhVO6eWih7tgfiO2SgAljzchjJ6HTlV4g-RlD6Wo46DaafVQpqpUQS2mmjdaxyMUC1HnAutOtE8',
                isArtist: true,
                glowColor: Color(0x3DC86464),
              ),
              _CuratedHistoryItem(
                title: 'Crimson Tide',
                subtitle: 'Album • Scarlet Dawn',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD_jvwuKdb7B0LepLmVl5r6SHwNBmuSjU7cBduaMN0eVaoXGUPME_zAenoi4LA1tezKkbeXcIqN7L99PTr-mTwseuRzO-eUx7hAk4hwqoO-cbYdGlVf0kPPhAyp8IYz9SRUNlL84gxrsohMmRBg-zPoneIx0Ojt6QYZIp-FqcwXIqJMwfgS5jZU6YHyIb7-fTptq3Cpjg5Qyew5AeGzsAa8FO8O5tCfGZTqbtgLKc4wOMsXnszXmYDDToLQ2MgQGOTakolP10uHu8Q',
                isArtist: false,
                glowColor: Color(0x3DFFB3B5),
              ),
            ],
          );
        }

        // Show actual history items
        return Column(
          children: songs.map((song) {
            const glowColors = [
              Color(0x3DFFB3B5),
              Color(0x3D64C8FF),
              Color(0x3DC86464),
              Color(0x3DFFD700),
            ];
            final glowColor = glowColors[song.title.hashCode.abs() % glowColors.length];

            return _RecentlyAddedItem(
              song: song,
              glowColor: glowColor,
              onTap: () {
                ref.read(playerStateProvider.notifier).playSong(song);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _RecentlyAddedItem extends StatefulWidget {
  final Song song;
  final Color glowColor;
  final VoidCallback onTap;

  const _RecentlyAddedItem({
    required this.song,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_RecentlyAddedItem> createState() => _RecentlyAddedItemState();
}

class _RecentlyAddedItemState extends State<_RecentlyAddedItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              // Artwork with glow
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.song.artworkUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.song.artworkUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.artist,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuratedHistoryItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isArtist;
  final Color glowColor;

  const _CuratedHistoryItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isArtist,
    required this.glowColor,
  });

  @override
  State<_CuratedHistoryItem> createState() => _CuratedHistoryItemState();
}

class _CuratedHistoryItemState extends State<_CuratedHistoryItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () {},
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              // Artwork with glow
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: widget.isArtist ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: widget.isArtist ? null : BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: widget.isArtist ? BorderRadius.circular(999) : BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-Page Wrapper Scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _SubPageScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const _SubPageScaffold({
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasActiveSong = ref.watch(playerStateProvider.select((s) => s.currentSong != null));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: body,
        ),
      ),
      bottomNavigationBar: hasActiveSong
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: MiniPlayer(),
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouTube Liked Songs View Widget
// ─────────────────────────────────────────────────────────────────────────────

class _YoutubeLikedSongsView extends ConsumerStatefulWidget {
  const _YoutubeLikedSongsView();

  @override
  ConsumerState<_YoutubeLikedSongsView> createState() => _YoutubeLikedSongsViewState();
}

class _YoutubeLikedSongsViewState extends ConsumerState<_YoutubeLikedSongsView> {
  late Future<List<MusicTrack>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<InnerTubeService>().fetchLikedSongs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<MusicTrack>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  snapshot.hasError
                      ? 'Error loading YouTube Liked Songs'
                      : 'No Liked Songs found or session expired',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _future = getIt<InnerTubeService>().fetchLikedSongs();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final tracks = snapshot.data!;

        return ListView.builder(
          itemCount: tracks.length,
          padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final title = track.title;
            final artist = track.artist;
            final artworkUrl = track.artworkUrl;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note, color: Colors.white),
                      ),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 28),
              onTap: () {
                final song = Song(
                  id: track.id,
                  title: title,
                  artist: artist,
                  album: track.album,
                  duration: track.duration,
                  artworkUrl: artworkUrl,
                  videoId: track.id,
                  source: 'YouTube Music',
                );
                ref.read(playerStateProvider.notifier).playSong(song);
              },
            );
          },
        );
      },
    );
  }
}


