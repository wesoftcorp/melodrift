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



// ── Custom YouTube API URL Provider ─────────────────────────────────────────────
final customYoutubeApiUrlProvider = StateNotifierProvider<CustomYoutubeApiUrlNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomYoutubeApiUrlNotifier(prefs);
});

class CustomYoutubeApiUrlNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  CustomYoutubeApiUrlNotifier(this._prefs) : super(_prefs.getString('custom_youtube_api_url') ?? '');

  Future<void> setUrl(String value) async {
    await _prefs.setString('custom_youtube_api_url', value);
    state = value;
  }
}

// ── Custom JioSaavn API URL Provider ─────────────────────────────────────────────
final customJioSaavnApiUrlProvider = StateNotifierProvider<CustomJioSaavnApiUrlNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomJioSaavnApiUrlNotifier(prefs);
});

class CustomJioSaavnApiUrlNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  CustomJioSaavnApiUrlNotifier(this._prefs) : super(_prefs.getString('custom_jiosaavn_api_url') ?? '');

  Future<void> setUrl(String value) async {
    await _prefs.setString('custom_jiosaavn_api_url', value);
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
              _buildYoutubeAccountItem(context, ref, theme),
              _buildDivider(theme),
              _buildSubscriptionItem(theme),
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
                title: const Text('Developer'),
                trailing: Text(
                  'Rajeev Upadhyay',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Website'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () async {
                  final url = Uri.parse('https://rajeevupadhyay.com');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Email'),
                trailing: const Icon(Icons.mail_outline_rounded, size: 16),
                onTap: () async {
                  final url = Uri.parse('mailto:rajeev.upadhyay@live.in');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildDivider(theme),
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

  Widget _buildYoutubeAccountItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final ytAccount = ref.watch(youtubeAuthProvider);

    if (ytAccount != null) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.red.withOpacity(0.15),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.red, size: 24),
        ),
        title: Text(ytAccount.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('YouTube Music Account Synced', style: TextStyle(color: Colors.green, fontSize: 12)),
        trailing: TextButton(
          onPressed: () => ref.read(youtubeAuthProvider.notifier).signOut(),
          child: const Text('Disconnect', style: TextStyle(color: Color(0xFFFF4500))),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.red),
      ),
      title: const Text('Sync YouTube Music Account', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Sync Liked Songs & Playlists via InnerTube'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showYoutubeCookieDialog(context, ref),
    );
  }

  void _showYoutubeCookieDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {

        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.sync_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Sync YouTube Music'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To sync your YouTube Music Liked Songs & Playlists via InnerTube:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '1. Open music.youtube.com in Browser\n'
                    '2. Press F12 -> Application -> Cookies\n'
                    '3. Copy the Cookie header string\n'
                    '4. Paste it below to authenticate',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Paste Cookie value here (e.g. SAPISID=...; SID=...)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final cookie = controller.text.trim();
                if (cookie.isNotEmpty) {
                  final success = await ref.read(youtubeAuthProvider.notifier).loginWithCookie(cookie);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'YouTube Account Synced Successfully!' : 'Invalid cookie string'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Connect & Sync'),
            ),
          ],
        );
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: Material(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
