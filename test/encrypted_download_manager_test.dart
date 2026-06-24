import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodrift/core/services/encrypted_download_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationCachePath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('melodrift_encrypt_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('encrypts downloads and restores playable bytes', () async {
    final manager = EncryptedDownloadManager(
      testMasterKey: base64Encode(List<int>.generate(32, (index) => index)),
    );
    final originalBytes = utf8.encode('melodrift-audio-bytes');

    final encryptedPath = await manager.downloadAndEncryptAudio(
      songId: 'song-1',
      title: 'Test Song',
      audioSourceFn: () async => originalBytes,
    );

    final encryptedBytes = await File(encryptedPath).readAsBytes();
    expect(encryptedBytes, isNot(originalBytes));
    expect(encryptedBytes.take(5), [0x4d, 0x44, 0x52, 0x46, 0x02]);

    final decryptedBytes = await manager.loadDecryptedAudioForPlayback(
      encryptedPath,
      'song-1',
    );
    expect(decryptedBytes, originalBytes);

    final playablePath = await manager.preparePlayableFile(
      encryptedFilePath: encryptedPath,
      songId: 'song-1',
    );
    expect(await File(playablePath).readAsBytes(), originalBytes);
  });
}
