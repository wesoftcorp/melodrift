import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../flavors.dart';
import '../../presentation/providers/duration_cache_provider.dart';
import '../../core/services/image_caching_service.dart';
import '../../core/utils/widget_rebuild_tracker.dart';
import '../screens/home_screen.dart' show homeLanguageProvider, kLanguageOptions;

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Online Services',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_queue),
            title: const Text('Enable Firebase Sync'),
            subtitle: const Text('Sync Collaborative Listening rooms & data'),
            value: ref.watch(firebaseEnabledProvider),
            onChanged: (value) async {
              if (value && F.isFoss) {
                _showFossInfoDialog(context);
                return;
              }
              await ref.read(firebaseEnabledProvider.notifier).toggle(value);
            },
          ),
          if (ref.watch(firebaseEnabledProvider)) ...[
            _buildAuthProfileTile(context, ref),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Mode'),
            subtitle: Text(_getThemeModeName(themeMode)),
            onTap: () => _showThemeSelectionDialog(context, ref, themeMode),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Content & Language',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final selected = ref.watch(homeLanguageProvider);
              final label = selected.contains('All') || selected.isEmpty
                  ? 'All Languages'
                  : selected.join(', ');
              return ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('Music Language'),
                subtitle: Text(label),
                onTap: () => _showLanguageSelector(context, ref),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Performance & Playback',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android)
            ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Android Battery Optimization'),
              subtitle: const Text('Prevent background playback interruptions'),
              onTap: () => _showBatteryWhitelistDialog(context),
            ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Optimizations & Caching'),
            subtitle: const Text('Manage pre-fetching, image caching, and view performance stats'),
            onTap: () => _showOptimizationsDialog(context),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Melodrift',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Version 1.0.0'),
                    const Text('Let the music drift.'),
                    const Divider(height: 24),
                    const Text('Developer: Rajeev Upadhyay'),
                    const Text('Email: rajeev.upadhyay@live.in'),
                    const Text('Website: rajeevupadhyay.com'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthProfileTile(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    if (user != null) {
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? NetworkImage(user.photoUrl!)
              : null,
          child: user.photoUrl == null || user.photoUrl!.isEmpty
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(user.displayName),
        subtitle: Text(user.email ?? 'Connected guest'),
        trailing: TextButton(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          child: const Text('Sign Out'),
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.login),
      title: const Text('Cloud Sync Account'),
      subtitle: const Text('Connect Google account for cloud backup'),
      trailing: ElevatedButton(
        onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
        child: const Text('Sign In'),
      ),
    );
  }

  void _showFossInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FOSS Edition Restriction'),
        content: const Text(
          'Melodrift FOSS Edition is compiled without any proprietary third-party dependencies, including Google Firebase SDKs.\n\n'
          'To use cloud sync features, please download and run the standard Melodrift build variant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getThemeModeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.light:
        return 'Light Theme';
      case AppThemeMode.dark:
        return 'Dark Theme';
      case AppThemeMode.amoled:
        return 'AMOLED Black';
    }
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final selected = ref.read(homeLanguageProvider);
          return AlertDialog(
            title: const Text('Music Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: kLanguageOptions.map((lang) {
                final isChecked = lang == 'All'
                    ? (selected.contains('All') || selected.isEmpty)
                    : selected.contains(lang);
                return CheckboxListTile(
                  title: Text(lang),
                  value: isChecked,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  onChanged: (_) {
                    final notifier = ref.read(homeLanguageProvider.notifier);
                    final prev = Set<String>.from(ref.read(homeLanguageProvider));
                    if (lang == 'All') {
                      notifier.state = {'All'};
                    } else if (prev.contains(lang)) {
                      prev.remove(lang);
                      notifier.state = prev.isEmpty ? {'All'} : (prev..remove('All'));
                    } else {
                      prev
                        ..remove('All')
                        ..add(lang);
                      notifier.state = Set<String>.from(prev);
                    }
                    setInner(() {});
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThemeSelectionDialog(BuildContext context, WidgetRef ref, AppThemeMode currentMode) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeName(mode)),
              value: mode,
              groupValue: currentMode,
              onChanged: (newMode) {
                if (newMode != null) {
                  ref.read(themeProvider.notifier).setThemeMode(newMode);
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBatteryWhitelistDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Battery Whitelist Instructions'),
        content: const SingleChildScrollView(
          child: Text(
            'To prevent Android from killing Melodrift during background audio streaming:\n\n'
            '1. Open system Settings.\n'
            '2. Go to Apps > Melodrift.\n'
            '3. Select Battery or Battery Usage.\n'
            '4. Choose "Unrestricted" or disable Battery Optimization.\n\n'
            'This ensures gapless background playback remains active.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showOptimizationsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final durStats = DurationCache.getStats();
            final imgStatsStr = CachedNetworkImageManager.getCacheStats();
            final rebuildsList = WidgetRebuildTracker.getHotWidgets();
            final rebuildStats = rebuildsList.isEmpty
                ? 'No hot widgets detected.'
                : rebuildsList.join('\n');

            return AlertDialog(
              title: const Text('Optimizations & Caching'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cache Statistics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Duration Cache: ${durStats.size} / ${durStats.maxSize} entries'),
                    Text(imgStatsStr),
                    const SizedBox(height: 16),
                    Text(
                      'Rebuild Tracking',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kDebugMode
                          ? 'Hot Widgets (rebuilds/sec):\n$rebuildStats'
                          : 'Rebuild tracker is active in debug mode.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              DurationCachingService().clearCache();
                              setDialogState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Duration cache cleared')),
                              );
                            },
                            child: const Text('Clear Durations'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              CachedNetworkImageManager.clearCache();
                              setDialogState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Image cache cleared')),
                              );
                            },
                            child: const Text('Clear Images'),
                          ),
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            WidgetRebuildTracker.reset();
                            setDialogState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Rebuild stats reset')),
                            );
                          },
                          child: const Text('Reset Rebuild Stats'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
