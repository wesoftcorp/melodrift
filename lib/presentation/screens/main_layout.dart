import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/router/app_router.gr.dart';
import '../providers/player_notifier.dart';
import '../providers/player_providers.dart';

@RoutePage()
class MainLayoutScreen extends ConsumerWidget {
  const MainLayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuilds when song presence changes (not on every position tick)
    final hasActiveSong = ref.watch(
      playerStateProvider.select((s) => s.currentSong != null),
    );

    return AutoTabsScaffold(
      routes: const [
        HomeRoute(),
        SearchRoute(),
        LibraryRoute(),
        SettingsRoute(),
      ],
      bottomNavigationBuilder: (_, tabsRouter) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActiveSong) const _MiniPlayer(),
            NavigationBar(
              selectedIndex: tabsRouter.activeIndex,
              onDestinationSelected: tabsRouter.setActiveIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Mini-player extracted into its own widget so only it rebuilds on position ticks.
class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Metadata: only rebuilds when song/playing/loading changes
    final song = ref.watch(currentSongProvider);
    final (:isPlaying, :isLoading) = ref.watch(playbackStateProvider);
    // Progress: rebuilds on every position tick — scoped only to this widget
    final progress = ref.watch(progressRatioProvider);

    if (song == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.router.push(const PlayerRoute()),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity < -300) {
            ref.read(playerStateProvider.notifier).next();
          } else if (velocity > 300) {
            ref.read(playerStateProvider.notifier).previous();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Gradient accent line at top
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                    // Content row
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Artwork
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: song.artworkUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: song.artworkUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.music_note),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.music_note),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Title + artist
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.artist,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Play/Pause button
                            IconButton(
                              icon: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isLoading)
                                    const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white30),
                                      ),
                                    ),
                                  Icon(
                                    isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                ],
                              ),
                              onPressed: () {
                                ref.read(playerStateProvider.notifier).togglePlay();
                              },
                            ),
                            // Next button
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: () {
                                ref.read(playerStateProvider.notifier).next();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Progress bar
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary),
                      ),
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
}
