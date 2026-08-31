import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/theme_provider.dart';
import '../../core/services/audio_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/player_notifier.dart';

import '../../flavors.dart';
import '../../presentation/providers/duration_cache_provider.dart';
import '../../core/services/image_caching_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/update_service.dart';
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

// ── Allow Explicit Content Provider ──────────────────────────────────────────
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

// ── Autoplay Continuous Radio Provider ───────────────────────────────────────
final autoplayEnabledProvider = StateNotifierProvider<AutoplayEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoplayEnabledNotifier(prefs);
});

class AutoplayEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  AutoplayEnabledNotifier(this._prefs) : super(_prefs.getBool('autoplay_enabled') ?? true);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('autoplay_enabled', value);
    state = value;
  }
}

// ── Streaming Quality Provider ───────────────────────────────────────────────
enum AudioStreamingQuality { auto, low, normal, high }

final streamingQualityProvider = StateNotifierProvider<StreamingQualityNotifier, AudioStreamingQuality>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StreamingQualityNotifier(prefs);
});

class StreamingQualityNotifier extends StateNotifier<AudioStreamingQuality> {
  final SharedPreferences _prefs;
  StreamingQualityNotifier(this._prefs) : super(_loadFromPrefs(_prefs));

  static AudioStreamingQuality _loadFromPrefs(SharedPreferences prefs) {
    final idx = prefs.getInt('streaming_quality') ?? 3; // Default High
    return AudioStreamingQuality.values[idx.clamp(0, AudioStreamingQuality.values.length - 1)];
  }

  Future<void> setQuality(AudioStreamingQuality quality) async {
    await _prefs.setInt('streaming_quality', quality.index);
    state = quality;
  }
}

// ── Equalizer Preset Provider ────────────────────────────────────────────────
final equalizerPresetProvider = StateNotifierProvider<EqualizerPresetNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return EqualizerPresetNotifier(prefs);
});

class EqualizerPresetNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  EqualizerPresetNotifier(this._prefs) : super(_prefs.getString('equalizer_preset') ?? 'Flat');

  Future<void> setPreset(String value) async {
    await _prefs.setString('equalizer_preset', value);
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
          onPressed: () {
            if (context.router.canPop()) {
              context.router.maybePop();
            } else {
              try {
                AutoTabsRouter.of(context).setActiveIndex(0);
              } catch (_) {
                context.router.maybePop();
              }
            }
          },
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
          // ── Section: Account & Cloud ───────────────────────────────────────
          const _SettingsSectionHeader(title: 'Account & Cloud Sync'),
          _SettingsCard(
            children: [
              _buildAccountProfileItem(context, ref, theme),
            ],
          ),

          // ── Section: Audio & Playback ──────────────────────────────────────
          const _SettingsSectionHeader(title: 'Audio & Playback'),
          _SettingsCard(
            children: [
              _buildEqualizerItem(context, ref, theme),
              _buildDivider(theme),
              _buildStreamingQualityItem(context, ref, theme),
              _buildDivider(theme),
              _buildSwitchItem(
                title: 'Autoplay Infinite Radio',
                subtitle: 'Keep playing similar songs when playlist ends',
                icon: Icons.all_inclusive_rounded,
                value: ref.watch(autoplayEnabledProvider),
                onChanged: (val) => ref.read(autoplayEnabledProvider.notifier).toggle(val),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildSleepTimerItem(context, ref, theme),
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
                title: 'Enable Cloud Sync',
                subtitle: 'Sync playlists and history across devices',
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
              _buildClearCacheItem(context, theme),
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
                title: const Text('Check for Updates'),
                subtitle: const Text('Tap to check for latest release'),
                leading: const Icon(Icons.system_update_rounded, color: Color(0xFFFF5F1F)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for updates...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  final update = await UpdateService.checkLatestRelease();
                  if (!context.mounted) return;
                  if (update != null) {
                    await UpdateService.showUpdateDialog(context, update, isManual: true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You are already on the latest version! (v1.2.0)'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Official Website'),
                subtitle: const Text('melodrift.rajeevupadhyay.com'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () async {
                  final url = Uri.parse('https://melodrift.rajeevupadhyay.com');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Support Email'),
                subtitle: const Text('rajeev.upadhyay@live.in'),
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
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '1.2.0 (Build 120)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              _buildDivider(theme),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () async {
                  final url = Uri.parse('https://melodrift.rajeevupadhyay.com/privacy.html');
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

  Widget _buildAccountProfileItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final user = ref.watch(authProvider);
    final syncStatus = ref.watch(cloudSyncStatusProvider);

    if (user != null) {
      final subtitle = user.email ?? 'Synced with Melodrift Cloud';
      return Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFF4500).withOpacity(0.15),
              backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
              child: user.photoUrl == null || user.photoUrl!.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF4500)),
                    )
                  : null,
            ),
            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            trailing: TextButton(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF4500))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      syncStatus == CloudSyncStatus.syncing
                          ? Icons.sync_rounded
                          : Icons.cloud_done_rounded,
                      size: 16,
                      color: syncStatus == CloudSyncStatus.syncing ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      syncStatus == CloudSyncStatus.syncing ? 'Syncing library...' : 'Cloud library backed up',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final success = await ref.read(cloudSyncServiceProvider).syncNow(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Library synced successfully' : 'Sync completed with offline cache'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 32),
      ),
      title: const Text('Sign In with Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: const Text('Sync playlists, favorites & listening history across devices', style: TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        if (F.isFoss) {
          _showFossInfoDialog(context);
          return;
        }
        if (!ref.read(firebaseEnabledProvider)) {
          await ref.read(firebaseEnabledProvider.notifier).toggle(true);
        }

        try {
          final loggedUser = await ref.read(authProvider.notifier).signInWithGoogle();
          if (context.mounted && loggedUser != null) {
            await ref.read(cloudSyncServiceProvider).syncNow(ref);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Welcome, ${loggedUser.displayName}! Cloud library & recommendations synced.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google Sign-In failed: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
    String? subtitle,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)) : null,
      value: value,
      activeColor: const Color(0xFFFF4500),
      onChanged: onChanged,
    );
  }

  Widget _buildStreamingQualityItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final quality = ref.watch(streamingQualityProvider);
    String label;
    switch (quality) {
      case AudioStreamingQuality.auto:
        label = 'Auto (Adaptive)';
        break;
      case AudioStreamingQuality.low:
        label = 'Low (96 kbps - Data Saver)';
        break;
      case AudioStreamingQuality.normal:
        label = 'Normal (160 kbps)';
        break;
      case AudioStreamingQuality.high:
        label = 'High (320 kbps - HD Audio)';
        break;
    }

    return ListTile(
      leading: const Icon(Icons.high_quality_rounded),
      title: const Text('Streaming Audio Quality'),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Streaming Audio Quality'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AudioStreamingQuality>(
                  title: const Text('Auto (Adaptive)'),
                  value: AudioStreamingQuality.auto,
                  groupValue: quality,
                  activeColor: const Color(0xFFFF4500),
                  onChanged: (val) {
                    if (val != null) ref.read(streamingQualityProvider.notifier).setQuality(val);
                    Navigator.pop(ctx);
                  },
                ),
                RadioListTile<AudioStreamingQuality>(
                  title: const Text('Low (96 kbps - Data Saver)'),
                  value: AudioStreamingQuality.low,
                  groupValue: quality,
                  activeColor: const Color(0xFFFF4500),
                  onChanged: (val) {
                    if (val != null) ref.read(streamingQualityProvider.notifier).setQuality(val);
                    Navigator.pop(ctx);
                  },
                ),
                RadioListTile<AudioStreamingQuality>(
                  title: const Text('Normal (160 kbps)'),
                  value: AudioStreamingQuality.normal,
                  groupValue: quality,
                  activeColor: const Color(0xFFFF4500),
                  onChanged: (val) {
                    if (val != null) ref.read(streamingQualityProvider.notifier).setQuality(val);
                    Navigator.pop(ctx);
                  },
                ),
                RadioListTile<AudioStreamingQuality>(
                  title: const Text('High (320 kbps - HD Audio)'),
                  value: AudioStreamingQuality.high,
                  groupValue: quality,
                  activeColor: const Color(0xFFFF4500),
                  onChanged: (val) {
                    if (val != null) ref.read(streamingQualityProvider.notifier).setQuality(val);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSleepTimerItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final playerState = ref.watch(playerStateProvider);
    final remaining = playerState.sleepTimeRemaining;
    final label = remaining != null && remaining > Duration.zero
        ? '${remaining.inMinutes + 1} min remaining'
        : 'Off';

    return ListTile(
      leading: const Icon(Icons.bedtime_rounded),
      title: const Text('Sleep Timer'),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Set Sleep Timer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Turn Off'),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).setSleepTimer(null);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('15 Minutes'),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).setSleepTimer(const Duration(minutes: 15));
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('30 Minutes'),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).setSleepTimer(const Duration(minutes: 30));
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('45 Minutes'),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).setSleepTimer(const Duration(minutes: 45));
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('60 Minutes'),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).setSleepTimer(const Duration(minutes: 60));
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildEqualizerItem(BuildContext context, WidgetRef ref, ThemeData theme) {
    final currentPreset = ref.watch(equalizerPresetProvider);
    return ListTile(
      leading: const Icon(Icons.graphic_eq_rounded),
      title: const Text('Equalizer Preset'),
      subtitle: Text('Current Mode: $currentPreset'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) {
            final presets = ['Flat', 'Bass Boost', 'Vocal Boost', 'Pop', 'Rock', 'Acoustic', 'Electronic'];
            return AlertDialog(
              title: const Text('Select Equalizer Preset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: presets.map((preset) {
                  return RadioListTile<String>(
                    title: Text(preset),
                    value: preset,
                    groupValue: currentPreset,
                    activeColor: const Color(0xFFFF4500),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(equalizerPresetProvider.notifier).setPreset(val);
                        try {
                          ref.read(audioHandlerProvider).setEqualizerPreset(val);
                        } catch (_) {}
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Equalizer preset changed to $val')),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClearCacheItem(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: const Icon(Icons.cleaning_services_rounded),
      title: const Text('Clear Cache'),
      subtitle: const Text('Free up storage by clearing cached images & temp files'),
      trailing: TextButton(
        onPressed: () => _handleClearCache(context),
        child: const Text('Clear', style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.bold)),
      ),
      onTap: () => _handleClearCache(context),
    );
  }

  void _handleClearCache(BuildContext context) async {
    await CachedNetworkImageManager.clearCache();
    DurationCachingService().clearCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('home_feed_cache_') || k.startsWith('artist_cache_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Color(0xFFFF4500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.language_rounded, color: Color(0xFFFF5F1F)),
                SizedBox(width: 10),
                Text('Music Languages'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kLanguageOptions.length,
                itemBuilder: (context, index) {
                  final lang = kLanguageOptions[index];
                  final isChecked = lang == 'All'
                      ? (selected.contains('All') || selected.isEmpty)
                      : selected.contains(lang);
                  return CheckboxListTile(
                    title: Text(lang),
                    value: isChecked,
                    activeColor: const Color(0xFFFF5F1F),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
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
