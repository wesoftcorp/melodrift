import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../flavors.dart';

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
              'Performance & Playback',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            title: const Text('Android Battery Optimization'),
            subtitle: const Text('Prevent background playback interruptions'),
            onTap: () => _showBatteryWhitelistDialog(context),
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Melodrift'),
            subtitle: Text('Version 1.0.0 (FOSS Edition)\nLet the music drift.'),
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
}
