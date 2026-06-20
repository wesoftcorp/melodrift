import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../core/theme/theme_provider.dart';

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
