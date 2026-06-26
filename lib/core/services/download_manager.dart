import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/logger.dart';

/// Stores downloaded audio files in plain format (no encryption) in the app's
/// cache directory. Files are stored as `{songId}_{sanitizedTitle}.m4a`.
class DownloadManager {
  static final _log = AppLogger('DownloadManager');
  static const _musicDirName = 'melodrift_downloads';

  late final Directory _downloadDir;
  bool _initialized = false;

  DownloadManager();

  /// Initializes the download directory.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final cacheDir = await getApplicationCacheDirectory();
      _downloadDir = Directory('${cacheDir.path}/$_musicDirName');
      if (!await _downloadDir.exists()) {
        await _downloadDir.create(recursive: true);
        _log.info('Created downloads directory: ${_downloadDir.path}');
      }
      _initialized = true;
    } catch (e) {
      _log.error('Failed to initialize download manager', e);
      rethrow;
    }
  }

  /// Stores the downloaded audio file from a temporary file.
  /// Returns the path to the stored file.
  Future<String> storeDownloadedFile({
    required String songId,
    required String title,
    required File tempFile,
  }) async {
    await initialize();
    if (!await tempFile.exists()) {
      throw Exception('Temp file does not exist: ${tempFile.path}');
    }

    // Sanitize title for use in filename.
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final fileName = '${songId}_$safeTitle.m4a';
    final file = File(p.join(_downloadDir.path, fileName));

    try {
      // Move the temp file to the final location.
      await tempFile.rename(file.path);
      _log.info('Stored downloaded file: ${file.path}');
      return file.path;
    } catch (e) {
      // If rename fails (e.g., across devices), fallback to copy.
      _log.warning('Rename failed, trying copy: $e');
      await tempFile.copy(file.path);
      await tempFile.delete();
      _log.info('Stored downloaded file via copy: ${file.path}');
      return file.path;
    }
  }

/// Returns the path to the stored file for [songId], or null if not found.
  Future<String?> getStoredPath(String songId) async {
    await initialize();
    final files = _downloadDir.listSync();
    for (final file in files) {
      if (file is File && file.path.contains('${songId}_')) {
        // Basic check; could be more precise.
        return file.path;
      }
    }
    return null;
  }

  /// Checks if a song is already downloaded.
  Future<bool> isDownloaded(String songId) async {
    final path = await getStoredPath(songId);
    return path != null && await File(path).exists();
  }

/// Deletes the stored file for [songId].
  Future<void> deleteStoredFile(String songId) async {
    await initialize();
    final files = _downloadDir.listSync();
    for (final file in files) {
      if (file is File && file.path.contains('${songId}_')) {
        await file.delete();
        _log.info('Deleted downloaded file: ${file.path}');
        return;
      }
    }
  }

  /// Deletes all stored files (useful for clearing cache).
  Future<void> clearAll() async {
    await initialize();
    final files = _downloadDir.listSync();
    for (final file in files) {
      if (file is File) {
        await file.delete();
      }
    }
    _log.info('Cleared all downloaded files');
  }
}

/// Provider for the download manager.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager();
});