import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/encrypted_download_manager.dart';
import '../../core/utils/logger.dart';

/// Hook for managing encrypted song downloads in the UI
/// 
/// Handles:
/// - Download state tracking (idle, downloading, completed, failed)
/// - Encrypted file storage
/// - Progress updates
/// - Error handling
/// - Cleanup on deletion
class EncryptedDownloadHook {
  static final _log = AppLogger('DownloadHook');

  final EncryptedDownloadManager _downloadManager;

  EncryptedDownloadHook(this._downloadManager);

  /// Download and encrypt a song for offline playback
  /// Returns download path on success
  Future<String?> downloadSongEncrypted({
    required String songId,
    required String title,
    required Future<List<int>> Function() audioSourceFn,
    required Future<void> Function(double progress)? onProgress,
  }) async {
    try {
      _log.info('Starting encrypted download: $title ($songId)');

      // Download and encrypt
      final filePath = await _downloadManager.downloadAndEncryptAudio(
        songId: songId,
        title: title,
        audioSourceFn: audioSourceFn,
      );

      _log.info('Download completed: $filePath');
      await onProgress?.call(1.0);
      return filePath;
    } catch (e) {
      _log.error('Download failed for $title', e);
      return null;
    }
  }

  /// Delete downloaded encrypted song
  Future<bool> deleteSongDownload(String encryptedFilePath) async {
    try {
      await _downloadManager.deleteEncryptedDownload(encryptedFilePath);
      _log.info('Deleted download: $encryptedFilePath');
      return true;
    } catch (e) {
      _log.error('Failed to delete download', e);
      return false;
    }
  }

  /// Get all downloaded songs
  Future<List<String>> getAllDownloads() async {
    try {
      return await _downloadManager.getAllEncryptedDownloads();
    } catch (e) {
      _log.error('Failed to get downloads', e);
      return [];
    }
  }

  /// Check if song is downloaded
  Future<bool> isSongDownloaded(String songId) async {
    try {
      return await _downloadManager.isDownloaded(songId);
    } catch (e) {
      _log.error('Failed to check download status', e);
      return false;
    }
  }

  /// Get download path for playing
  Future<String?> getDownloadPath(String songId) async {
    try {
      return await _downloadManager.getDownloadPath(songId);
    } catch (e) {
      _log.error('Failed to get download path', e);
      return null;
    }
  }
}

/// Riverpod provider for encrypted download hook
final encryptedDownloadHookProvider = Provider<EncryptedDownloadHook>((ref) {
  final downloadManager = ref.watch(encryptedDownloadManagerProvider);
  return EncryptedDownloadHook(downloadManager);
});

/// State provider for tracking download progress
class DownloadProgress {
  final String songId;
  final String title;
  final double progress; // 0.0 to 1.0
  final bool isDownloading;
  final bool isCompleted;
  final String? error;

  const DownloadProgress({
    required this.songId,
    required this.title,
    this.progress = 0.0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
  });

  DownloadProgress copyWith({
    String? songId,
    String? title,
    double? progress,
    bool? isDownloading,
    bool? isCompleted,
    String? error,
  }) {
    return DownloadProgress(
      songId: songId ?? this.songId,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

/// Provider to track ongoing download progress
final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, Map<String, DownloadProgress>>(
  (ref) => DownloadProgressNotifier(),
);

class DownloadProgressNotifier
    extends StateNotifier<Map<String, DownloadProgress>> {
  static final _log = AppLogger('DownloadProgress');

  DownloadProgressNotifier() : super({});

  /// Start tracking a download
  void startDownload(String songId, String title) {
    state = {
      ...state,
      songId: DownloadProgress(
        songId: songId,
        title: title,
        isDownloading: true,
      ),
    };
    _log.debug('Started tracking download: $songId');
  }

  /// Update progress
  void updateProgress(String songId, double progress) {
    if (state.containsKey(songId)) {
      state = {
        ...state,
        songId: state[songId]!.copyWith(progress: progress),
      };
    }
  }

  /// Mark download as completed
  void completeDownload(String songId) {
    if (state.containsKey(songId)) {
      state = {
        ...state,
        songId: state[songId]!.copyWith(
          isDownloading: false,
          isCompleted: true,
          progress: 1.0,
        ),
      };
      _log.debug('Download completed: $songId');
    }
  }

  /// Mark download as failed
  void failDownload(String songId, String error) {
    if (state.containsKey(songId)) {
      state = {
        ...state,
        songId: state[songId]!.copyWith(
          isDownloading: false,
          error: error,
        ),
      };
      _log.error('Download failed: $songId - $error');
    }
  }

  /// Remove from tracking
  void removeDownload(String songId) {
    state = {...state}..remove(songId);
  }

  /// Clear all downloads
  void clearAll() {
    state = {};
  }
}
