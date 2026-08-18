import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

final youtubeAuthServiceProvider = Provider<YoutubeAuthService>((ref) {
  return YoutubeAuthService();
});

class YoutubeAuthAccount {
  final String displayName;
  final String email;
  final String photoUrl;
  final String cookie;

  YoutubeAuthAccount({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.cookie,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'cookie': cookie,
      };

  factory YoutubeAuthAccount.fromJson(Map<String, dynamic> json) => YoutubeAuthAccount(
        displayName: json['displayName']?.toString() ?? 'YouTube User',
        email: json['email']?.toString() ?? '',
        photoUrl: json['photoUrl']?.toString() ?? '',
        cookie: json['cookie']?.toString() ?? '',
      );
}

class YoutubeAuthService {
  final _log = AppLogger('YoutubeAuthService');
  static const _cookieKey = 'yt_auth_cookie';
  static const _accountInfoKey = 'yt_account_info';

  String? _cookie;
  YoutubeAuthAccount? _account;

  String? get cookie => _cookie;
  YoutubeAuthAccount? get account => _account;
  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cookie = prefs.getString(_cookieKey);
      final accStr = prefs.getString(_accountInfoKey);
      if (accStr != null && accStr.isNotEmpty) {
        _account = YoutubeAuthAccount.fromJson(jsonDecode(accStr) as Map<String, dynamic>);
      }
    } catch (e) {
      _log.error('Failed to initialize YoutubeAuthService: $e');
    }
  }


  Future<bool> saveCookie(String rawCookie, {String? name, String? email, String? photoUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanCookie = rawCookie.trim();
      if (cleanCookie.isEmpty) return false;

      _cookie = cleanCookie;
      await prefs.setString(_cookieKey, cleanCookie);

      _account = YoutubeAuthAccount(
        displayName: name ?? 'YouTube Music User',
        email: email ?? '',
        photoUrl: photoUrl ?? '',
        cookie: cleanCookie,
      );

      await prefs.setString(_accountInfoKey, jsonEncode(_account!.toJson()));
      _log.info('YouTube Music auth cookie successfully saved.');
      return true;
    } catch (e) {
      _log.error('Failed to save YouTube auth cookie: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cookieKey);
      await prefs.remove(_accountInfoKey);
      _cookie = null;
      _account = null;
      _log.info('Signed out from YouTube Music.');
    } catch (e) {
      _log.error('Failed to sign out: $e');
    }
  }

  /// Generates the standard InnerTube headers including Cookie & SAPISIDHASH if present.
  Map<String, String> getInnerTubeHeaders() {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'X-YouTube-Client-Name': '67', // YTM Web Client ID
      'X-YouTube-Client-Version': '1.20240101.01.00',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'Content-Type': 'application/json',
    };

    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie!;

      // Extract SAPISID cookie if available for SAPISIDHASH calculation
      final sapisid = _extractCookieValue(_cookie!, 'SAPISID') ?? _extractCookieValue(_cookie!, '__Secure-3PAPISID');
      if (sapisid != null && sapisid.isNotEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        const origin = 'https://music.youtube.com';
        final strToHash = '$timestamp $sapisid $origin';

        final hash = sha1.convert(utf8.encode(strToHash)).toString();
        headers['Authorization'] = 'SAPISIDHASH ${timestamp}_$hash';
      }
    }

    return headers;
  }

  String? _extractCookieValue(String cookieString, String key) {
    final parts = cookieString.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$key=')) {
        return trimmed.substring(key.length + 1);
      }
    }
    return null;
  }
}
