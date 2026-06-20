import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  // Typed Helper Methods
  Future<bool?> readBool(String key) async {
    final String? val = await read(key);
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> writeBool(String key, bool value) async {
    await write(key, value ? 'true' : 'false');
  }

  Future<int?> readInt(String key) async {
    final String? val = await read(key);
    if (val == null) return null;
    return int.tryParse(val);
  }

  Future<void> writeInt(String key, int value) async {
    await write(key, value.toString());
  }
}
