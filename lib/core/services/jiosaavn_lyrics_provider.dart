import 'package:dio/dio.dart';
import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';
import 'lrclib_provider.dart';

class JioSaavnLyricsProvider implements LyricsProvider {
  final Dio _dio;
  final _log = AppLogger('JioSaavnLyricsProvider');

  static const _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  ];

  static const _apiHosts = [
    'https://jiosaavn.softcorpllc.workers.dev',
    'https://saavn.dev',
    'https://jiosaavn-api-sigma.vercel.app',
  ];

  JioSaavnLyricsProvider(this._dio);

  @override
  String get name => 'jiosaavn';

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    final cleanTitleStr = LrcLibProvider.cleanTitle(title);
    final cleanArtistStr = LrcLibProvider.cleanArtist(artist);
    _log.info('Fetching lyrics from JioSaavn for: "$cleanTitleStr" by "$cleanArtistStr"');

    final dioOptions = Options(
      headers: {
        'User-Agent': _userAgents.first,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );

    // Try custom endpoints with browser User-Agent
    for (final host in _apiHosts) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$host/api/search/songs',
          queryParameters: {'query': '$cleanTitleStr $cleanArtistStr'},
          options: dioOptions,
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.data != null) {
          final body = response.data!;
          final results = (body['data']?['results'] ?? body['results']) as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            // Find best matching song
            final targetTitleLower = cleanTitleStr.toLowerCase();
            dynamic matchedSong = results.first;
            for (final r in results) {
              if (r is Map<String, dynamic>) {
                final rTitle = (r['title'] ?? r['name'] ?? '').toString().toLowerCase();
                if (rTitle.contains(targetTitleLower) || targetTitleLower.contains(rTitle)) {
                  matchedSong = r;
                  break;
                }
              }
            }

            final songId = matchedSong['id']?.toString();
            if (songId != null && songId.isNotEmpty) {
              final lyricsResponse = await _dio.get<Map<String, dynamic>>(
                '$host/api/songs/$songId/lyrics',
                options: dioOptions,
              ).timeout(const Duration(seconds: 4));

              if (lyricsResponse.statusCode == 200 && lyricsResponse.data != null) {
                final lyricsData = lyricsResponse.data!['data'] ?? lyricsResponse.data!;
                final rawLyrics = lyricsData['lyrics']?.toString();
                if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
                  _log.info('Successfully fetched JioSaavn lyrics from $host');
                  return _parseJioSaavnLyrics(rawLyrics, duration);
                }
              }
            }
          }
        }
      } catch (e) {
        _log.warning('JioSaavnLyricsProvider host $host failed: $e');
      }
    }

    // Official JioSaavn fallback
    try {
      final officialSearch = await _dio.get<Map<String, dynamic>>(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'autocomplete.get',
          'query': '$cleanTitleStr $cleanArtistStr',
          '_format': 'json',
          '_marker': '0',
        },
        options: dioOptions,
      ).timeout(const Duration(seconds: 4));

      if (officialSearch.statusCode == 200 && officialSearch.data != null) {
        final songs = officialSearch.data!['songs']?['data'] as List<dynamic>?;
        if (songs != null && songs.isNotEmpty) {
          final id = songs.first['id']?.toString();
          if (id != null) {
            final lyricsResp = await _dio.get<Map<String, dynamic>>(
              'https://www.jiosaavn.com/api.php',
              queryParameters: {
                '__call': 'lyrics.getLyrics',
                'lyrics_id': id,
                '_format': 'json',
                '_marker': '0',
                'ctx': 'web64s',
              },
              options: dioOptions,
            ).timeout(const Duration(seconds: 4));

            if (lyricsResp.statusCode == 200 && lyricsResp.data != null) {
              final rawLyrics = lyricsResp.data!['lyrics']?.toString();
              if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
                _log.info('Successfully fetched JioSaavn lyrics from official API');
                return _parseJioSaavnLyrics(rawLyrics, duration);
              }
            }
          }
        }
      }
    } catch (e) {
      _log.warning('Official JioSaavn API lyrics failed: $e');
    }

    return [];
  }

  List<LyricLine> _parseJioSaavnLyrics(String rawLyrics, Duration duration) {
    final cleanText = rawLyrics
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'");

    final rawLines = cleanText.split('\n');
    final validLines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (validLines.isEmpty) return [];

    final lyricLines = <LyricLine>[];
    final totalDurationMs = duration.inMilliseconds > 10000 ? duration.inMilliseconds : (validLines.length * 3500);
    final stepMs = (totalDurationMs / (validLines.length + 1)).round();

    int timeMs = 0;
    for (final text in validLines) {
      lyricLines.add(LyricLine(timeMs: timeMs, text: text));
      timeMs += stepMs;
    }
    return lyricLines;
  }
}
