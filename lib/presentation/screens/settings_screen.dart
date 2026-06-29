import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../flavors.dart';
import '../../presentation/providers/duration_cache_provider.dart';
import '../../core/services/image_caching_service.dart';
import '../../core/utils/widget_rebuild_tracker.dart';
import '../../core/services/audio_quality_preferences.dart';
import '../providers/audio_quality_provider.dart';
import '../screens/home_screen.dart' show homeLanguageProvider, kLanguageOptions;

// ── WiFi Only Downloads Provider ─────────────────────────────────────────────
final downloadOnlyWifiProvider = StateNotifierProvider<DownloadOnlyWifiNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DownloadOnlyWifiNotifier(prefs);
});

class DownloadOnlyWifiNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  DownloadOnlyWifiNotifier(this._prefs) : super(_prefs.getBool('download_only_wifi') ?? false);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('download_only_wifi', value);
    state = value;
  }
}

// ── Playback & Content Providers ─────────────────────────────────────────────
final crossfadeEnabledProvider = StateNotifierProvider<CrossfadeEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CrossfadeEnabledNotifier(prefs);
});

class CrossfadeEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  CrossfadeEnabledNotifier(this._prefs) : super(_prefs.getBool('crossfade_enabled') ?? false);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('crossfade_enabled', value);
    state = value;
  }
}

final gaplessPlaybackProvider = StateNotifierProvider<GaplessPlaybackNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GaplessPlaybackNotifier(prefs);
});

class GaplessPlaybackNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  GaplessPlaybackNotifier(this._prefs) : super(_prefs.getBool('gapless_playback') ?? true);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('gapless_playback', value);
    state = value;
  }
}

final allowExplicitContentProvider = StateNotifierProvider<AllowExplicitContentNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AllowExplicitContentNotifier(prefs);
});

class AllowExplicitContentNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  AllowExplicitContentNotifier(this._prefs) : super(_prefs.getBool('allow_explicit_content') ?? true);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('allow_explicit_content', value);
    state = value;
  }
}

// ── Settings Screen ──────────────────────────────────────────────────────────
@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: const Color(0xFFFF4500),
              size: 22,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).setThemeMode(
                  isDark ? AppThemeMode.light : AppThemeMode.dark);
            },
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Section: Account ───────────────────────────────────────────────
          const _SettingsSectionHeader(title: 'Account'),
          _SettingsCard(
            children: [
              _buildGoogleAccountItem(context, ref, theme),
              _buildDivider(theme),
              _buildSubscriptionItem(theme),
            ],
          ),

          // ── Section: Playback ──────────────────────────────────────────────
          const _SettingsSectionHeader(title: 'Playback'),
          _SettingsCard(
            children: [
              _buildAudioQualityItem(context, ref, theme),
              _buildDivider(theme),
              _buildSwitchItem(
                title: 'Crossfade',
                icon: Icons.shuffle_rounded,
                value: ref.watch(crossfadeEnabledProvider),
                onChanged: (val) => ref.read(crossfadeEnabledProvider.notifier).toggle(val),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildSwitchItem(
                title: 'Gapless Playback',
                icon: Icons.format_align_justify_rounded,
                value: ref.watch(gaplessPlaybackProvider),
                onChanged: (val) => ref.read(gaplessPlaybackProvider.notifier).toggle(val),
                theme: theme,
              ),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                _buildDivider(theme),
                ListTile(
                  leading: const Icon(Icons.battery_saver_rounded),
                  title: const Text('Android Battery Optimization'),
                  subtitle: const Text('Prevent background playback interruptions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBatteryWhitelistDialog(context),
                ),
              ],
            ],
          ),

          // ── Section: Content & Display ─────────────────────────────────────
          const _SettingsSectionHeader(title: 'Content & Display'),
          _SettingsCard(
            children: [
              _buildSwitchItem(
                title: 'Allow Explicit Content',
                icon: Icons.explicit_rounded,
                value: ref.watch(allowExplicitContentProvider),
                onChanged: (val) => ref.read(allowExplicitContentProvider.notifier).toggle(val),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildLanguageItem(context, ref, theme),
              _buildDivider(theme),
              _buildThemeModeItem(context, ref, theme, themeMode),
              _buildDivider(theme),
              _buildSwitchItem(
                title: 'Enable Firebase Sync',
                icon: Icons.cloud_queue_rounded,
                value: ref.watch(firebaseEnabledProvider),
                onChanged: (value) async {
                  if (value && F.isFoss) {
                    _showFossInfoDialog(context);
                    return;
                  }
                  await ref.read(firebaseEnabledProvider.notifier).toggle(value);
                },
                theme: theme,
              ),
            ],
          ),

          // ── Section: Storage & Network ─────────────────────────────────────
          const _SettingsSectionHeader(title: 'Storage & Network'),
          _SettingsCard(
            children: [
              _buildSwitchItem(
                title: 'Download only over Wi-Fi',
                icon: Icons.wifi_rounded,
                value: ref.watch(downloadOnlyWifiProvider),
                onChanged: (val) => ref.read(downloadOnlyWifiProvider.notifier).toggle(val),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildStorageProgressItem(theme),
              _buildDivider(theme),
              _buildStorageActionsItem(context, theme),
            ],
          ),

          // ── Section: About ─────────────────────────────────────────────────
          const _SettingsSectionHeader(title: 'About'),
          _SettingsCard(
            children: [
              ListTile(
                title: const Text('Version'),
                trailing: Text(
                  '1.0.0 (Nocturnal)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () {},
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () async {
                  final url = Uri.parse('https://rockstarrajeev.github.io/melodrift/privacy-policy.html');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'Made with ❤️ for Melodrift listeners.',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outline.withOpacity(0.05),
    );
  }

  Widget _buildGoogleAccountItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final user = ref.watch(authProvider);

    if (user != null) {
      return ListTile(
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
        trailing: TextButton(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF4500))),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.account_circle_outlined, size: 28),
      ),
      title: const Text('Sign In with Google', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Sync library & listening history'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        if (F.isFoss) {
          _showFossInfoDialog(context);
          return;
        }
        if (!ref.read(firebaseEnabledProvider)) {
          await ref.read(firebaseEnabledProvider.notifier).toggle(true);
        }
        await ref.read(authProvider.notifier).signInWithGoogle();
      },
    );
  }

  Widget _buildSubscriptionItem(ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4500).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF4500)),
      ),
      title: const Text('Melodrift Plus', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Active • Renews Oct 24', style: TextStyle(color: Color(0xFFFF4500))),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildAudioQualityItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final settings = ref.watch(audioQualityProvider);
    return ListTile(
      leading: const Icon(Icons.high_quality_rounded),
      title: const Text('Audio Quality'),
      subtitle: Text('Streaming: ${settings.streamingQuality} • Download: ${settings.downloadQuality}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showAudioQualitySelector(context, ref, settings),
    );
  }

  void _showAudioQualitySelector(BuildContext context, WidgetRef ref, AudioQualitySettings settings) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Audio Quality Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Streaming Quality'),
                subtitle: Text(settings.streamingQuality),
                onTap: () {
                  Navigator.pop(context);
                  _showQualitySelector(
                    context: context,
                    title: 'Streaming Quality',
                    currentValue: settings.streamingQuality,
                    options: streamingQualityOptions,
                    onSelected: (quality) => ref
                        .read(audioQualityProvider.notifier)
                        .setStreamingQuality(quality),
                  );
                },
              ),
              ListTile(
                title: const Text('Download Quality'),
                subtitle: Text(settings.downloadQuality),
                onTap: () {
                  Navigator.pop(context);
                  _showQualitySelector(
                    context: context,
                    title: 'Download Quality',
                    currentValue: settings.downloadQuality,
                    options: downloadQualityOptions,
                    onSelected: (quality) => ref
                        .read(audioQualityProvider.notifier)
                        .setDownloadQuality(quality),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      activeColor: const Color(0xFFFF4500),
      onChanged: onChanged,
    );
  }

  Widget _buildLanguageItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final selected = ref.watch(homeLanguageProvider);
    final label = selected.contains('All') || selected.isEmpty
        ? 'All Languages'
        : selected.join(', ');

    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: const Text('Music Language'),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showLanguageSelector(context, ref),
    );
  }

  Widget _buildThemeModeItem(BuildContext context, WidgetRef ref, ThemeData theme, AppThemeMode themeMode) {
    return ListTile(
      leading: const Icon(Icons.dark_mode_rounded),
      title: const Text('Theme Mode'),
      subtitle: Text(_getThemeModeName(themeMode)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showThemeSelectionDialog(context, ref, themeMode),
    );
  }

  Widget _buildStorageProgressItem(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cache Size',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '1.2 GB / 5.0 GB',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: 0.24, // 24% placeholder
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4500)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageActionsItem(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF4500), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _showOptimizationsDialog(context),
              child: const Text(
                'Clear Cache',
                style: TextStyle(
                  color: Color(0xFFFF4500),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dialog Actions
  // ───────────────────────────────────────────────────────────────────────────

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
              activeColor: const Color(0xFFFF4500),
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: kLanguageOptions.map((lang) {
                  final isChecked = lang == 'All'
                      ? (selected.contains('All') || selected.isEmpty)
                      : selected.contains(lang);
                  return CheckboxListTile(
                    title: Text(lang),
                    value: isChecked,
                    activeColor: const Color(0xFFFF4500),
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
              activeColor: const Color(0xFFFF4500),
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

// ─────────────────────────────────────────────────────────────────────────────
// Styled section components
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFFF4500),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
