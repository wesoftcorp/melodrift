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
    final theme = Theme.of(context);

    return AutoTabsScaffold(
      extendBody: true,
      routes: const [
        HomeRoute(),
        SearchRoute(),
        LibraryRoute(),
        SettingsRoute(),
      ],
      bottomNavigationBuilder: (_, tabsRouter) {
        final isDark = theme.brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActiveSong)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: MiniPlayer(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.75)
                          : theme.colorScheme.surfaceContainerLowest.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5F1F).withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: 'Home',
                          tabsRouter: tabsRouter,
                          theme: theme,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: Icons.search_outlined,
                          selectedIcon: Icons.search,
                          label: 'Browse',
                          tabsRouter: tabsRouter,
                          theme: theme,
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: Icons.library_music_outlined,
                          selectedIcon: Icons.library_music,
                          label: 'Library',
                          tabsRouter: tabsRouter,
                          theme: theme,
                        ),
                        _buildNavItem(
                          index: 3,
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings,
                          label: 'Settings',
                          tabsRouter: tabsRouter,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required TabsRouter tabsRouter,
    required ThemeData theme,
  }) {
    final isActive = tabsRouter.activeIndex == index;
    const activeColor = Color(0xFFFF4500); // Orange-red matching style="color: rgb(255, 69, 0);"
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => tabsRouter.setActiveIndex(index),
        child: AnimatedScale(
          scale: isActive ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? selectedIcon : icon,
                    color: isActive ? activeColor : inactiveColor,
                    size: 24,
                  ),
                  if (isActive)
                    Positioned(
                      bottom: -6,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : inactiveColor,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini-player extracted into its own widget so only it rebuilds on position ticks.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

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
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(140), // ~0.55 opacity
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(25),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Removed top gradient line for cleaner nocturnal-echo glass look
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
