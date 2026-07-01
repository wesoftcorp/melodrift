import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

class GlassBottomNav extends StatelessWidget {
  final TabsRouter tabsRouter;
  final bool isDark;

  const GlassBottomNav({
    required this.tabsRouter,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
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
