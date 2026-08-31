import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';
import 'lrclib_provider.dart';

class KuGouProvider implements LyricsProvider {
  final Dio _dio;
  final _log = AppLogger('KuGouProvider');

  KuGouProvider(this._dio);

  @override
  String get name => 'kugou';

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    final cleanTitleStr = LrcLibProvider.cleanTitle(title);
    final cleanArtistStr = LrcLibProvider.cleanArtist(artist);
    const searchUrl = 'https://lyrics.kugou.com/search';
    const downloadUrl = 'https://lyrics.kugou.com/download';

    try {
      _log.info('Searching KuGou lyrics for: "$cleanTitleStr" by "$cleanArtistStr"');
      final searchResponse = await _dio.get<dynamic>(
        searchUrl,
        queryParameters: {
          'ver': 1,
          'man': 'yes',
          'client': 'pc',
          'keyword': '$cleanTitleStr $cleanArtistStr',
          'duration': duration.inMilliseconds,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (searchResponse.statusCode != 200 || searchResponse.data == null) {
        _log.warning('KuGou search request failed');
        return [];
      }

      final searchData = searchResponse.data;
      if (searchData is! Map<String, dynamic>) return [];

      final candidates = searchData['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        _log.info('No KuGou lyrics candidates found');
        return [];
      }

      // Pick the first/best candidate
      final bestCandidate = candidates.first as Map<String, dynamic>?;
      if (bestCandidate == null) return [];

      final id = bestCandidate['id'];
      final accesskey = bestCandidate['accesskey'];

      if (id == null || accesskey == null) return [];

      _log.info('Downloading KuGou lyric id: $id');
      final downloadResponse = await _dio.get<dynamic>(
        downloadUrl,
        queryParameters: {
          'ver': 1,
          'client': 'pc',
          'id': id,
          'accesskey': accesskey,
          'fmt': 'lrc',
        },
      );

      if (downloadResponse.statusCode != 200 || downloadResponse.data == null) {
        _log.warning('KuGou lyrics download failed');
        return [];
      }

      final downloadData = downloadResponse.data;
      if (downloadData is! Map<String, dynamic>) return [];

      final base64Content = downloadData['content'] as String?;
      if (base64Content == null || base64Content.isEmpty) {
        _log.warning('Empty content in KuGou download response');
        return [];
      }

      final decodedText = utf8.decode(base64.decode(base64Content));
      return _parseLrc(decodedText);
    } catch (e, s) {
      _log.error('KuGou failed to fetch/parse lyrics: $e', e, s);
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
}
