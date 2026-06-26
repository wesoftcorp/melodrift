import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../flavors.dart';
import '../../presentation/providers/duration_cache_provider.dart';
import '../../core/services/image_caching_service.dart';
import '../../core/utils/widget_rebuild_tracker.dart';
import '../../core/services/audio_quality_preferences.dart';
import '../providers/audio_quality_provider.dart';
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
          // ── Google Account (always visible) ────────────────────────
          _buildGoogleAccountSection(context, ref, theme),
          const Divider(),
          _buildAudioQualitySection(context, ref, theme),
          const Divider(),
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

  Widget _buildAudioQualitySection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final settings = ref.watch(audioQualityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Audio Quality',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.graphic_eq_rounded),
          title: const Text('Streaming Quality'),
          subtitle: Text(settings.streamingQuality),
          onTap: () => _showQualitySelector(
            context: context,
            title: 'Streaming Quality',
            currentValue: settings.streamingQuality,
            options: streamingQualityOptions,
            onSelected: (quality) => ref
                .read(audioQualityProvider.notifier)
                .setStreamingQuality(quality),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_for_offline_outlined),
          title: const Text('Download Quality'),
          subtitle: Text(settings.downloadQuality),
          onTap: () => _showQualitySelector(
            context: context,
            title: 'Download Quality',
            currentValue: settings.downloadQuality,
            options: downloadQualityOptions,
            onSelected: (quality) => ref
                .read(audioQualityProvider.notifier)
                .setDownloadQuality(quality),
          ),
        ),
      ],
    );
  }

  /// Google account card — always visible, no Firebase toggle required.
  Widget _buildGoogleAccountSection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final user = ref.watch(authProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: user != null
            ? ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user.email ?? 'Google Account'),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_circle_outlined,
                            color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Sign In with Google',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sync your library, playlists, and listening history across devices.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                        onPressed: () async {
                          if (F.isFoss) {
                            _showFossInfoDialog(context);
                            return;
                          }
                          // Auto-enable Firebase if user explicitly signs in
                          if (!ref.read(firebaseEnabledProvider)) {
                            await ref.read(firebaseEnabledProvider.notifier).toggle(true);
                          }
                          await ref.read(authProvider.notifier).signInWithGoogle();
                        },
                      ),
                    ),
                  ],
                ),
              ),
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

  void _showQualitySelector({
    required BuildContext context,
    required String title,
    required String currentValue,
    required List<String> options,
    required Future<void> Function(String quality) onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((quality) {
            return RadioListTile<String>(
              title: Text(quality),
              value: quality,
              groupValue: currentValue,
              onChanged: (value) async {
                if (value == null) return;
                await onSelected(value);
                if (context.mounted) Navigator.pop(context);
              },
            );
          }).toList(),
        ),
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
                      notifier.setLanguages({'All'});
                    } else if (prev.contains(lang)) {
                      prev.remove(lang);
                      notifier.setLanguages(prev.isEmpty ? {'All'} : (prev..remove('All')));
                    } else {
                      prev
                        ..remove('All')
                        ..add(lang);
                      notifier.setLanguages(Set<String>.from(prev));
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
