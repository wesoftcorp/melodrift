import 'package:dio/dio.dart';
import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class YouLyPlusProvider implements LyricsProvider {
  final Dio _dio;
  final _log = AppLogger('YouLyPlusProvider');

  YouLyPlusProvider(this._dio);

  @override
  String get name => 'youlyplus';

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    const url = 'https://youlyplus.top/api/lyrics';
    try {
      _log.info('Fetching lyrics from YouLyPlus for: $title - $artist');
      final response = await _dio.get<dynamic>(
        url,
        queryParameters: {
          'title': title,
          'artist': artist,
          'duration': duration.inSeconds,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final syncedLyrics = data['syncedLyrics'] as String? ?? data['lrc'] as String?;
          final plainLyrics = data['plainLyrics'] as String? ?? data['text'] as String?;

          if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
            return _parseLrc(syncedLyrics);
          } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
            return _parsePlain(plainLyrics);
          }
        }
      }
      return [];
    } catch (e, s) {
      _log.error('YouLyPlus failed to fetch lyrics: $e', e, s);
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
}
