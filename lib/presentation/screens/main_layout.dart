import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../app/router/app_router.gr.dart';
import '../providers/player_notifier.dart';
import '../widgets/layout/glass_bottom_nav.dart';
import '../widgets/layout/mini_player.dart';

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
            GlassBottomNav(
              tabsRouter: tabsRouter,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}
