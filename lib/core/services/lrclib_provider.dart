import 'package:dio/dio.dart';
import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class LrcLibProvider implements LyricsProvider {
  final Dio _dio;
  final _log = AppLogger('LrcLibProvider');
  final Map<String, List<LyricLine>> _cache = {};

  LrcLibProvider(this._dio);

  @override
  String get name => 'lrclib';

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    final cleanTitleStr = cleanTitle(title);
    final cleanArtistStr = cleanArtist(artist);
    final cacheKey = '${cleanTitleStr.toLowerCase()}_${cleanArtistStr.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      _log.debug('Returning cached lyrics for: $cleanTitleStr - $cleanArtistStr');
      return _cache[cacheKey]!;
    }

    try {
      _log.info('Fetching lyrics from LRCLIB for: "$cleanTitleStr" by "$cleanArtistStr" (${duration.inSeconds}s)');
      List<LyricLine> lyrics = [];

      // Stage 1: Exact match query with duration filter
      if (duration.inSeconds > 10) {
        lyrics = await _queryExact(cleanTitleStr, cleanArtistStr, duration.inSeconds);
      }

      // Stage 2: Search by track_name & artist_name with best match scoring
      if (lyrics.isEmpty) {
        lyrics = await _querySearch(
          {'track_name': cleanTitleStr, 'artist_name': cleanArtistStr},
          cleanTitleStr,
          cleanArtistStr,
          duration,
        );
      }

      // Stage 3: Search by general query (q) if Stage 2 yields no results
      if (lyrics.isEmpty && cleanArtistStr.isNotEmpty) {
        lyrics = await _querySearch(
          {'q': '$cleanTitleStr $cleanArtistStr'},
          cleanTitleStr,
          cleanArtistStr,
          duration,
        );
      }

      // Stage 4: Search by clean title alone with duration verification
      if (lyrics.isEmpty) {
        lyrics = await _querySearch(
          {'track_name': cleanTitleStr},
          cleanTitleStr,
          cleanArtistStr,
          duration,
        );
      }

      if (lyrics.isNotEmpty) {
        if (_cache.length > 100) {
          _cache.remove(_cache.keys.first);
        }
        _cache[cacheKey] = lyrics;
      }
      return lyrics;
    } catch (e, s) {
      _log.error('LRCLIB failed to fetch lyrics: $e', e, s);
      return [];
    }
  }

  Future<List<LyricLine>> _queryExact(String title, String artist, int durationSeconds) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          'duration': durationSeconds,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return _parseLrc(synced);
        }
        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) {
          return _parsePlain(plain);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<LyricLine>> _querySearch(
    Map<String, dynamic> params,
    String targetTitle,
    String targetArtist,
    Duration targetDuration,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://lrclib.net/api/search',
        queryParameters: params,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final results = response.data as List<dynamic>;

        // Score results to find the truest match (prefer syncedLyrics, duration match within 10s, title match)
        Map<String, dynamic>? bestItem;
        int bestScore = -1;

        final targetTitleLower = targetTitle.toLowerCase();
        final targetArtistLower = targetArtist.toLowerCase();
        final targetDurSec = targetDuration.inSeconds;

        for (final item in results) {
          if (item is! Map<String, dynamic>) continue;

          final syncedLyrics = item['syncedLyrics'] as String?;
          final plainLyrics = item['plainLyrics'] as String?;
          if ((syncedLyrics == null || syncedLyrics.trim().isEmpty) &&
              (plainLyrics == null || plainLyrics.trim().isEmpty)) {
            continue;
          }

          final trackName = (item['trackName'] as String? ?? '').toLowerCase();
          final artistName = (item['artistName'] as String? ?? '').toLowerCase();
          final dur = (item['duration'] as num?)?.toInt() ?? 0;

          int score = 0;
          if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
            score += 50; // Heavily prioritize synced lyrics
          }
          if (trackName.contains(targetTitleLower) || targetTitleLower.contains(trackName)) {
            score += 30;
          }
          if (targetArtistLower.isNotEmpty &&
              (artistName.contains(targetArtistLower) || targetArtistLower.contains(artistName))) {
            score += 25;
          }
          if (targetDurSec > 0 && dur > 0) {
            final diff = (dur - targetDurSec).abs();
            if (diff <= 4) {
              score += 20;
            } else if (diff <= 12) {
              score += 10;
            }
          }

          if (score > bestScore) {
            bestScore = score;
            bestItem = item;
          }
        }

        if (bestItem != null && bestScore >= 30) {
          final synced = bestItem['syncedLyrics'] as String?;
          if (synced != null && synced.trim().isNotEmpty) {
            return _parseLrc(synced);
          }
          final plain = bestItem['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            return _parsePlain(plain);
          }
        }
      }
    } catch (_) {}
    return [];
  }

  List<LyricLine> _parseLrc(String lrcText) {
    final lines = lrcText.split('\n');
    final lyricLines = <LyricLine>[];
    final lrcRegex = RegExp(r'^\[(\d+):(\d+)(?:\.(\d+))?\](.*)$');

    for (var line in lines) {
      line = line.trim();
      final match = lrcRegex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
        final timeMs = (min * 60 + sec) * 1000 + ms;
        final text = match.group(4)!.trim();
        lyricLines.add(LyricLine(timeMs: timeMs, text: text));
      }
    }
    return lyricLines;
  }

  List<LyricLine> _parsePlain(String plainText) {
    final lines = plainText.split('\n');
    final lyricLines = <LyricLine>[];
    int timeMs = 0;

    for (final line in lines) {
      final text = line.trim();
      if (text.isNotEmpty) {
        lyricLines.add(LyricLine(timeMs: timeMs, text: text));
        timeMs += 3000;
      }
    }
    return lyricLines;
  }

  static String cleanTitle(String title, [String? artist]) {
    var s = title;
    // Handle SoundCloud/YouTube "Artist - Title" format
    if (s.contains(' - ') && !s.contains(RegExp(r'\s*-(?:\s*official|\s*lyrics|\s*audio)', caseSensitive: false))) {
      final parts = s.split(' - ');
      if (parts.length == 2 && parts[1].trim().isNotEmpty) {
        if (artist != null && artist.isNotEmpty) {
          final artLower = artist.toLowerCase();
          if (parts[0].toLowerCase().contains(artLower) || artLower.contains(parts[0].toLowerCase())) {
            s = parts[1];
          }
        }
      }
    }

    // Strip common YouTube/audio junk
    s = s.replaceAll(RegExp(r'\s*\([^)]*official[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*official[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*video[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*video[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*audio[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*audio[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*lyric[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*lyric[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*visualizer[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*remaster[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*from[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*from[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*soundtrack[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*original[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*feat[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\([^)]*ft[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*feat[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*ft[^\]]*\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\|.*$'), ''); // Strip trailing "| artist / info"
    s = s.replaceAll(RegExp(r'\s*-(?:\s*official|\s*lyrics|\s*audio).*$', caseSensitive: false), '');
    return s.trim();
  }

  static String cleanArtist(String artist) {
    var a = artist;
    a = a.replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '');
    a = a.replaceAll(RegExp(r'\s*vevo$', caseSensitive: false), '');
    if (a.contains(',')) return a.split(',').first.trim();
    if (a.contains('&')) return a.split('&').first.trim();
    if (a.contains(';')) return a.split(';').first.trim();
    return a.trim();
  }
}


