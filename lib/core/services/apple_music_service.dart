import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

class AppleMusicService {
  final Dio _dio;
  final _log = AppLogger('AppleMusicService');
  final Map<String, String?> _motionArtworkCache = {};

  AppleMusicService(this._dio);

  /// Searches iTunes API and crawls Apple Music web page to find
  /// the .m3u8 or .mp4 motion artwork video URL.
  Future<String?> getMotionArtworkUrl(String title, String artist) async {
    final cacheKey = '$title - $artist'.toLowerCase().trim();
    if (_motionArtworkCache.containsKey(cacheKey)) {
      return _motionArtworkCache[cacheKey];
    }

    try {
      _log.info('Searching iTunes API for: $title $artist');

      // Use <dynamic> to avoid hard cast failure when iTunes returns an unexpected
      // content-type (e.g. text/javascript or text/html instead of application/json).
      final searchResponse = await _dio.get<dynamic>(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': '$title $artist',
          'media': 'music',
          'entity': 'song',
          'limit': 1,
        },
        options: Options(responseType: ResponseType.json),
      ).timeout(const Duration(seconds: 8));

      if (searchResponse.statusCode != 200 || searchResponse.data == null) {
        _log.warning('iTunes Search API failed with status ${searchResponse.statusCode}');
        _motionArtworkCache[cacheKey] = null;
        return null;
      }

      // Safely extract the body as a Map regardless of how Dio decoded it
      Map<String, dynamic>? bodyMap;
      final raw = searchResponse.data;
      if (raw is Map<String, dynamic>) {
        bodyMap = raw;
      } else if (raw is String) {
        try {
          bodyMap = jsonDecode(raw) as Map<String, dynamic>?;
        } catch (_) {
          _log.warning('iTunes response was a non-JSON string, skipping');
          _motionArtworkCache[cacheKey] = null;
          return null;
        }
      }

      if (bodyMap == null) {
        _motionArtworkCache[cacheKey] = null;
        return null;
      }

      final results = bodyMap['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        _log.warning('No iTunes results found for: $title $artist');
        _motionArtworkCache[cacheKey] = null;
        return null;
      }

      final trackMap = results.first as Map<String, dynamic>;
      final albumPageUrl = trackMap['collectionViewUrl'] as String?
          ?? trackMap['trackViewUrl'] as String?;
      if (albumPageUrl == null || albumPageUrl.isEmpty) {
        _log.warning('No album page URL found in iTunes response');
        _motionArtworkCache[cacheKey] = null;
        return null;
      }

      _log.info('Crawling Apple Music album page: $albumPageUrl');
      final pageResponse = await _dio.get<String>(
        albumPageUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      ).timeout(const Duration(seconds: 10));

      if (pageResponse.statusCode != 200 || pageResponse.data == null) {
        _log.warning('Failed to fetch Apple Music album page');
        _motionArtworkCache[cacheKey] = null;
        return null;
      }

      final html = pageResponse.data!;
      final regex = RegExp(
        r'https?://[^\s"]*?(?:editorialVideo|motion-artwork)[^\s"]*?\.(?:m3u8|mp4)',
      );
      final match = regex.firstMatch(html);

      if (match != null) {
        final matchedUrl = match.group(0);
        _log.info('Found Apple Music motion artwork URL: $matchedUrl');
        _motionArtworkCache[cacheKey] = matchedUrl;
        return matchedUrl;
      }

      _log.info('No motion artwork found on Apple Music album page');
      _motionArtworkCache[cacheKey] = null;
      return null;
    } catch (e, s) {
      _log.error('Failed to get Apple Music motion artwork: $e', e, s);
      _motionArtworkCache[cacheKey] = null;
      return null;
    }
  }
}
