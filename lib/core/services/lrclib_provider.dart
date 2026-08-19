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
    final cleanTitleStr = _cleanTitle(title);
    final cleanArtistStr = _cleanArtist(artist);
    final cacheKey = '${cleanTitleStr.toLowerCase()}_${cleanArtistStr.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      _log.debug('Returning cached lyrics for: $cleanTitleStr - $cleanArtistStr');
      return _cache[cacheKey]!;
    }

    const url = 'https://lrclib.net/api/search';
    try {
      _log.info('Fetching lyrics from LRCLIB for: $cleanTitleStr - $cleanArtistStr');
      final response = await _dio.get<dynamic>(
        url,
        queryParameters: {
          'track_name': cleanTitleStr,
          'artist_name': cleanArtistStr,
          if (duration > Duration.zero) 'duration': duration.inSeconds,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );


      List<LyricLine> lyrics = [];
      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final results = response.data as List<dynamic>;
        final bestMatch = results.first as Map<String, dynamic>;
        final syncedLyrics = bestMatch['syncedLyrics'] as String?;
        final plainLyrics = bestMatch['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          lyrics = _parseLrc(syncedLyrics);
        } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
          lyrics = _parsePlain(plainLyrics);
        }
      }

      if (_cache.length > 100) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = lyrics;
      return lyrics;
    } catch (e, s) {
      _log.error('LRCLIB failed to fetch lyrics: $e', e, s);
      return [];
    }
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
        timeMs += 3000; // 3 seconds per line sequential fallback
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


