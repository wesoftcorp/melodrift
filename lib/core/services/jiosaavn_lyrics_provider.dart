import 'package:dio/dio.dart';
import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class JioSaavnLyricsProvider implements LyricsProvider {
  final Dio _dio;
  final _log = AppLogger('JioSaavnLyricsProvider');
  final String _baseUrl;

  JioSaavnLyricsProvider(this._dio, {String baseUrl = 'https://jiosaavn.softcorpllc.workers.dev'}) : _baseUrl = baseUrl;

  @override
  String get name => 'jiosaavn';

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    try {
      final cleanTitleStr = _cleanTitle(title);
      final cleanArtistStr = _cleanArtist(artist);

      _log.info('Fetching lyrics from JioSaavn API for: $cleanTitleStr - $cleanArtistStr');
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/search/songs',
        queryParameters: {'query': '$cleanTitleStr $cleanArtistStr'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data!;
        final success = body['success'] as bool? ?? false;
        if (success && body['data'] != null) {
          final results = body['data']['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final songId = results.first['id'] as String?;
            if (songId != null && songId.isNotEmpty) {
              final lyricsResponse = await _dio.get<Map<String, dynamic>>(
                '$_baseUrl/api/songs/$songId/lyrics',
              ).timeout(const Duration(seconds: 5));

              if (lyricsResponse.statusCode == 200 && lyricsResponse.data != null) {
                final lyricsData = lyricsResponse.data!['data'];
                if (lyricsData != null && lyricsData['lyrics'] != null) {
                  final rawLyrics = lyricsData['lyrics'].toString();
                  if (rawLyrics.trim().isNotEmpty) {
                    return _parseJioSaavnLyrics(rawLyrics);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      _log.warning('JioSaavnLyricsProvider direct fetch failed: $e');
    }
    return [];
  }

  List<LyricLine> _parseJioSaavnLyrics(String rawLyrics) {
    final cleanText = rawLyrics
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'");

    final lines = cleanText.split('\n');
    final lyricLines = <LyricLine>[];
    int timeMs = 0;

    for (final line in lines) {
      final text = line.trim();
      if (text.isNotEmpty) {
        lyricLines.add(LyricLine(timeMs: timeMs, text: text));
        timeMs += 3500;
      }
    }
    return lyricLines;
  }

  String _cleanTitle(String title) {
    var s = title;
    s = s.replaceAll(RegExp(r'\s*\([^)]*from[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*soundtrack[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*original[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*feat[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*ft[^)]*\)', caseSensitive: false), '');
    return s.trim();
  }

  String _cleanArtist(String artist) {
    if (artist.contains(',')) return artist.split(',').first.trim();
    if (artist.contains('&')) return artist.split('&').first.trim();
    return artist.trim();
  }
}
