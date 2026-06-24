import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/logger.dart';

/// Manages encrypted downloads - app-only playback
/// 
/// Features:
/// - Encrypt audio files with AES-256 (app-specific key)
/// - Store in app cache (auto-deleted on uninstall)
/// - Prevent external player access (.melodrift extension)
/// - Maintain file integrity (SHA256 verification)
/// - Simple download/delete management
class EncryptedDownloadManager {
  static final _log = AppLogger('EncryptedDownload');
  static const _masterKeyStorageKey = 'melodrift_download_master_key_v1';
  static const _storage = FlutterSecureStorage();

  final String? _testMasterKey;

  /// Directory for encrypted downloads (auto-cleaned on uninstall)
  late Directory _downloadDir;
  bool _initialized = false;

  EncryptedDownloadManager({String? testMasterKey}) : _testMasterKey = testMasterKey;

  /// Initialize download directory
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final cacheDir = await getApplicationCacheDirectory();
      _downloadDir = Directory('${cacheDir.path}/melodrift_secure_downloads');

      // Create directory if it doesn't exist
      if (!await _downloadDir.exists()) {
        await _downloadDir.create(recursive: true);
        _log.info('Created encrypted downloads directory: ${_downloadDir.path}');
      }

      _initialized = true;
      _log.info('EncryptedDownloadManager initialized');
    } catch (e) {
      _log.error('Failed to initialize download manager', e);
      rethrow;
    }
  }

  /// Download and obfuscate an audio file
  /// Returns the encrypted file path (.melodrift extension)
  Future<String> downloadAndEncryptAudio({
    required String songId,
    required String title,
    required Future<List<int>> Function() audioSourceFn,
  }) async {
    try {
      await initialize();

      _log.info('Starting encrypted download for: $title ($songId)');

      // Fetch audio data
      final audioBytes = await audioSourceFn();
      _log.debug('Audio fetched: ${audioBytes.length} bytes');

      final encryptedBytes = await _encryptAudioBytes(audioBytes, songId);
      _log.debug('Audio encrypted: ${encryptedBytes.length} bytes');

      // Create encrypted filename with .melodrift extension (prevents external player access)
      final encryptedFileName =
          '${songId}_${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.melodrift';
      final filePath = '${_downloadDir.path}/$encryptedFileName';

      // Write encrypted file
      final file = File(filePath);
      await file.writeAsBytes(encryptedBytes);

      // Calculate and store integrity hash
      final hash = sha256.convert(encryptedBytes).toString();
      await _storeIntegrityHash(songId, hash);

      _log.info('Download completed: $filePath (${encryptedBytes.length} bytes)');
      return filePath;
    } catch (e) {
      _log.error('Failed to download and encrypt audio', e);
      rethrow;
    }
  }

  /// Load and decrypt audio for playback
  /// Returns decrypted audio bytes for just_audio playback
  Future<List<int>> loadDecryptedAudioForPlayback(
    String encryptedFilePath,
    String songId,
  ) async {
    try {
      if (!File(encryptedFilePath).existsSync()) {
        throw Exception('Encrypted file not found: $encryptedFilePath');
      }

      // Verify file integrity
      final encryptedBytes = await File(encryptedFilePath).readAsBytes();
      await _verifyIntegrity(songId, encryptedBytes);

      _log.debug('Loading encrypted audio: $encryptedFilePath');

      // Decrypt for playback
      final decryptedBytes = await _decryptAudioBytes(encryptedBytes, songId);

      _log.debug('Audio decrypted: ${decryptedBytes.length} bytes');
      return decryptedBytes;
    } catch (e) {
      _log.error('Failed to load decrypted audio', e);
      rethrow;
    }
  }

  /// Decrypt an app-only download into a temporary playable file.
  Future<String> preparePlayableFile({
    required String encryptedFilePath,
    required String songId,
  }) async {
    final decryptedBytes = await loadDecryptedAudioForPlayback(
      encryptedFilePath,
      songId,
    );
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/melodrift_playback_$songId.m4a');
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    return tempFile.path;
  }

  /// Delete encrypted download file
  Future<void> deleteEncryptedDownload(String encryptedFilePath) async {
    try {
      final file = File(encryptedFilePath);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted encrypted download: $encryptedFilePath');
      }
    } catch (e) {
      _log.error('Failed to delete encrypted download', e);
      rethrow;
    }
  }

  /// Get list of all encrypted downloads
  Future<List<String>> getAllEncryptedDownloads() async {
    try {
      await initialize();

      final files = _downloadDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.melodrift'))
          .map((f) => f.path)
          .toList();

      return files;
    } catch (e) {
      _log.error('Failed to get downloads list', e);
      return [];
    }
  }

  /// Get encrypted file size
  Future<int> getEncryptedFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      _log.error('Failed to get file size', e);
      return 0;
    }
  }

  /// Check if song is already downloaded
  Future<bool> isDownloaded(String songId) async {
    try {
      await initialize();

      final files = _downloadDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains(songId) && f.path.endsWith('.melodrift'))
          .toList();

      return files.isNotEmpty;
    } catch (e) {
      _log.error('Failed to check download status', e);
      return false;
    }
  }

  /// Get download path for a song ID
  Future<String?> getDownloadPath(String songId) async {
    try {
      await initialize();

      final files = _downloadDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains(songId) && f.path.endsWith('.melodrift'))
          .toList();

      return files.isNotEmpty ? files.first.path : null;
    } catch (e) {
      _log.error('Failed to get download path', e);
      return null;
    }
  }

  // ========== Private Methods ==========

  /// Encrypt audio bytes with AES-256 using a per-song derived key and random IV.
  Future<List<int>> _encryptAudioBytes(List<int> data, String songId) async {
    try {
      final key = await _generateEncryptionKey(songId);
      final ivBytes = _randomBytes(16);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(key)),
          mode: encrypt.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );

      final encrypted = encrypter.encryptBytes(data, iv: iv).bytes;

      // Header: magic bytes + version + IV length + IV + ciphertext.
      return [0x4d, 0x44, 0x52, 0x46, 0x02, ivBytes.length] + ivBytes + encrypted;
    } catch (e) {
      _log.error('Encryption failed', e);
      rethrow;
    }
  }

  /// Decrypt audio bytes encrypted by [_encryptAudioBytes].
  Future<List<int>> _decryptAudioBytes(List<int> data, String songId) async {
    try {
      if (data.length < 22 ||
          data[0] != 0x4d ||
          data[1] != 0x44 ||
          data[2] != 0x52 ||
          data[3] != 0x46 ||
          data[4] != 0x02) {
        throw Exception('Invalid encrypted file format');
      }

      final ivLength = data[5];
      const ivStart = 6;
      final ivEnd = ivStart + ivLength;
      if (ivLength != 16 || data.length <= ivEnd) {
        throw Exception('Invalid encrypted file header');
      }

      final key = await _generateEncryptionKey(songId);
      final iv = encrypt.IV(Uint8List.fromList(data.sublist(ivStart, ivEnd)));
      final encryptedData = encrypt.Encrypted(Uint8List.fromList(data.sublist(ivEnd)));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(key)),
          mode: encrypt.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );

      return encrypter.decryptBytes(encryptedData, iv: iv);
    } catch (e) {
      _log.error('Decryption failed', e);
      rethrow;
    }
  }

  /// Generate a stable 32-byte per-song AES key from the app master key.
  Future<List<int>> _generateEncryptionKey(String songId) async {
    final masterKey = await _getOrCreateMasterKey();
    final hash = sha256.convert([...base64Decode(masterKey), ...utf8.encode(songId)]);
    return hash.bytes;
  }

  Future<String> _getOrCreateMasterKey() async {
    final testMasterKey = _testMasterKey;
    if (testMasterKey != null) return testMasterKey;

    final existing = await _storage.read(key: _masterKeyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final key = base64Encode(_randomBytes(32));
    await _storage.write(key: _masterKeyStorageKey, value: key);
    return key;
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Store integrity hash for verification
  Future<void> _storeIntegrityHash(String songId, String hash) async {
    try {
      final hashFile = File('${_downloadDir.path}/.hashes');
      List<String> lines = [];
      if (await hashFile.exists()) {
        lines = await hashFile.readAsLines();
      }

      // Remove old entry for this song
      lines.removeWhere((String l) => l.startsWith('$songId:'));

      // Add new entry
      lines.add('$songId:$hash');

      // Write back
      await hashFile.writeAsString(lines.join('\n'));
    } catch (e) {
      _log.error('Failed to store integrity hash', e);
    }
  }

  /// Verify file integrity using stored hash
  Future<void> _verifyIntegrity(String songId, List<int> fileBytes) async {
    try {
      final hashFile = File('${_downloadDir.path}/.hashes');
      if (!await hashFile.exists()) {
        _log.info('Hash file not found, skipping verification');
        return;
      }

      final lines = await hashFile.readAsLines();
      String hashLine = '';
      for (final line in lines) {
        if (line.startsWith('$songId:')) {
          hashLine = line;
          break;
        }
      }

      if (hashLine.isEmpty) {
        _log.info('No hash found for $songId');
        return;
      }

      final storedHash = hashLine.split(':')[1];
      final currentHash = sha256.convert(fileBytes).toString();

      if (storedHash != currentHash) {
        throw Exception('Integrity check failed - file may be corrupted');
      }

      _log.debug('Integrity verified for $songId');
    } catch (e) {
      _log.error('Integrity verification failed', e);
      rethrow;
    }
  }
}

/// Riverpod provider for encrypted download manager
final encryptedDownloadManagerProvider =
    Provider<EncryptedDownloadManager>((ref) {
  return EncryptedDownloadManager();
});

/// Provider to check if a song is downloaded
final isSongDownloadedProvider =
    FutureProvider.family<bool, String>((ref, songId) async {
  final manager = ref.watch(encryptedDownloadManagerProvider);
  return manager.isDownloaded(songId);
});

/// Provider to get download path for a song
final songDownloadPathProvider =
    FutureProvider.family<String?, String>((ref, songId) async {
  final manager = ref.watch(encryptedDownloadManagerProvider);
  return manager.getDownloadPath(songId);
});

/// Provider to get all downloads
final allDownloadsProvider = FutureProvider<List<String>>((ref) async {
  final manager = ref.watch(encryptedDownloadManagerProvider);
  return manager.getAllEncryptedDownloads();
});
