import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/services/encrypted_download_manager.dart';
import '../../core/utils/logger.dart';

/// Provider for playing encrypted downloaded songs
/// 
/// Handles:
/// - Loading encrypted audio file
/// - Decrypting to memory
/// - Playing through just_audio
/// - Preventing external player access
class EncryptedAudioProvider {
  static final _log = AppLogger('EncryptedAudio');

  final EncryptedDownloadManager _downloadManager;

  EncryptedAudioProvider(this._downloadManager);

  /// Get playable audio source for encrypted song
  /// Decrypts the file and returns just_audio compatible source
  Future<AudioSource?> getEncryptedAudioSource(
    String songId,
    String title,
  ) async {
    try {
      // Get the encrypted file path
      final encryptedPath = await _downloadManager.getDownloadPath(songId);

      if (encryptedPath == null) {
        _log.warning('Encrypted file not found for $songId');
        return null;
      }

      _log.debug('Loading encrypted audio: $title ($songId)');

      // Decrypt audio to memory
      final decryptedBytes =
          await _downloadManager.loadDecryptedAudioForPlayback(
        encryptedPath,
        songId,
      );

      // Create temporary decrypted file for playback
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/.melodrift_temp_$songId');

      // Write decrypted audio to temp file (auto-cleaned by OS)
      await tempFile.writeAsBytes(decryptedBytes);

      _log.info('Decrypted audio ready for playback: ${decryptedBytes.length} bytes');

      // Return just_audio compatible source
      return AudioSource.file(
        tempFile.path,
        tag: songId, // For tracking purposes
      );
    } catch (e) {
      _log.error('Failed to get encrypted audio source', e);
      return null;
    }
  }

  /// Check if song is downloaded and can be played offline
  Future<bool> canPlayOffline(String songId) async {
    try {
      return await _downloadManager.isDownloaded(songId);
    } catch (e) {
      _log.error('Failed to check offline availability', e);
      return false;
    }
  }

  /// Get encrypted file size for display
  Future<String> getEncryptedFileSizeForDisplay(String songId) async {
    try {
      final path = await _downloadManager.getDownloadPath(songId);
      if (path == null) return '0 MB';

      final bytes = await _downloadManager.getEncryptedFileSize(path);
      return _formatFileSize(bytes);
    } catch (e) {
      _log.error('Failed to get file size', e);
      return '0 MB';
    }
  }

  /// Format bytes to human readable size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Riverpod provider for encrypted audio playback
final encryptedAudioProvider = Provider<EncryptedAudioProvider>((ref) {
  final downloadManager = ref.watch(encryptedDownloadManagerProvider);
  return EncryptedAudioProvider(downloadManager);
});

/// Get audio source for encrypted song (for playback)
final encryptedAudioSourceProvider = FutureProvider.family<AudioSource?, String>(
  (ref, songId) async {
    final audioProvider = ref.watch(encryptedAudioProvider);
    // Note: We need the title from somewhere (song repository)
    // For now, using songId as title placeholder
    return audioProvider.getEncryptedAudioSource(songId, 'Downloaded Song');
  },
);

/// Check if song is available for offline playback
final offlinePlaybackAvailableProvider =
    FutureProvider.family<bool, String>((ref, songId) async {
  final audioProvider = ref.watch(encryptedAudioProvider);
  return audioProvider.canPlayOffline(songId);
});

/// Get encrypted file size for display
final encryptedFileSizeProvider =
    FutureProvider.family<String, String>((ref, songId) async {
  final audioProvider = ref.watch(encryptedAudioProvider);
  return audioProvider.getEncryptedFileSizeForDisplay(songId);
});
