import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';

class UpdateInfo {
  final String version;
  final String title;
  final String changelog;
  final String? downloadUrl;
  final String htmlUrl;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.title,
    required this.changelog,
    this.downloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
  });
}

class UpdateService {
  static final _log = AppLogger('UpdateService');
  static const String _githubRepo = 'wesoftcorp/melodrift';
  static const String _releaseApiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';

  /// Check if a newer version is available
  static Future<UpdateInfo?> checkLatestRelease() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Melodrift-App',
          },
        ),
      );

      final response = await dio.get<Map<String, dynamic>>(_releaseApiUrl);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final tagName = data['tag_name']?.toString() ?? '';
        final latestVersion = tagName.replaceAll(RegExp(r'[^0-9\.]'), '');
        final releaseTitle = data['name']?.toString() ?? 'Version $latestVersion';
        final releaseNotes = data['body']?.toString() ?? 'Performance improvements and bug fixes.';
        final htmlUrl = data['html_url']?.toString() ?? 'https://melodrift.rajeevupadhyay.com';
        final publishedAt = DateTime.tryParse(data['published_at']?.toString() ?? '') ?? DateTime.now();

        final assets = (data['assets'] as List<dynamic>?) ?? [];
        String? directDownloadUrl;

        if (Platform.isAndroid) {
          for (final asset in assets) {
            final name = asset['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk') && !name.contains('foss')) {
              directDownloadUrl = asset['browser_download_url']?.toString();
              break;
            }
          }
        } else if (Platform.isWindows) {
          for (final asset in assets) {
            final name = asset['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.msix') || name.endsWith('.exe') || name.endsWith('.zip')) {
              directDownloadUrl = asset['browser_download_url']?.toString();
              break;
            }
          }
        }

        // Compare with current installed app version
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(currentVersion, latestVersion)) {
          _log.info('New update available: $latestVersion (current: $currentVersion)');
          return UpdateInfo(
            version: latestVersion,
            title: releaseTitle,
            changelog: releaseNotes,
            downloadUrl: directDownloadUrl,
            htmlUrl: htmlUrl,
            publishedAt: publishedAt,
          );
        } else {
          _log.info('App is up to date ($currentVersion)');
        }
      }
    } catch (e) {
      _log.warning('Could not fetch latest release: $e');
    }
    return null;
  }

  /// Compares semantic version strings (e.g. "1.3.0" > "1.2.0")
  static bool _isNewerVersion(String current, String latest) {
    try {
      final curParts = current.split('.').map(int.parse).toList();
      final latParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latParts.length; i++) {
        final cur = i < curParts.length ? curParts[i] : 0;
        final lat = latParts[i];
        if (lat > cur) return true;
        if (lat < cur) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Show the interactive update dialog to the user
  static Future<void> showUpdateDialog(BuildContext context, UpdateInfo update, {bool isManual = false}) async {
    if (!context.mounted) return;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: !isManual,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5F1F).withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFF5F1F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      'Version ${update.version}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(160)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'What\'s New:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      update.changelog.isNotEmpty ? update.changelog : 'General improvements, speed enhancements, and bug fixes.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Later', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(140))),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5F1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Update Now'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startDownloadAndInstall(context, update);
              },
            ),
          ],
        );
      },
    );
  }

  /// Download the update with a progress modal and launch installer
  static Future<void> _startDownloadAndInstall(BuildContext context, UpdateInfo update) async {
    if (!context.mounted) return;

    if (update.downloadUrl == null) {
      final uri = Uri.parse(update.htmlUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
    final ValueNotifier<String> statusNotifier = ValueNotifier('Starting download...');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (progCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.cloud_download_rounded, size: 44, color: Color(0xFFFF5F1F)),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (_, status, __) => Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, progress, __) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withAlpha(50),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress > 0 ? '${(progress * 100).toStringAsFixed(1)}%' : 'Connecting...',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = update.downloadUrl!.split('/').last;
      final savePath = '${tempDir.path}/$fileName';

      await dio.download(
        update.downloadUrl!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            statusNotifier.value = 'Downloading update (${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB)';
          }
        },
      );

      statusNotifier.value = 'Launching installer...';
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Open the downloaded file using OpenFilex for native Android PackageInstaller / Windows Shell
      final result = await OpenFilex.open(savePath);
      _log.info('OpenFilex installer result: ${result.type}, message: ${result.message}');

      if (result.type != ResultType.done) {
        final uri = Uri.parse(update.htmlUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _log.error('Download failed: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update download failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Open Browser',
              textColor: Colors.white,
              onPressed: () => launchUrl(Uri.parse(update.htmlUrl), mode: LaunchMode.externalApplication),
            ),
          ),
        );
      }
    }
  }
}
