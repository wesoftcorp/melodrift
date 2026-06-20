import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../domain/entities/lyrics.dart';
import '../../domain/repositories/lyrics_repository.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LyricsRepositoryImpl(dio);
});

class LyricsRepositoryImpl implements LyricsRepository {
  final Dio _dio;

  LyricsRepositoryImpl(this._dio);

  @override
  Future<List<LyricLine>> getLyrics(
    String songId,
    String title,
    String artist,
    Duration duration,
  ) async {
    // 1. Try fetching from LRCLIB
    try {
      final response = await _dio.get<dynamic>(
        'https://lrclib.net/api/search',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          'duration': duration.inSeconds,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final bestMatch = (response.data as List).first;
        final syncedLyrics = bestMatch['syncedLyrics'] as String?;
        final plainLyrics = bestMatch['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          return _parseLrc(syncedLyrics);
        } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
          return _parsePlain(plainLyrics);
        }
      }
    } catch (_) {
      // Fail silently to try fallback
    }

    // 2. Fallback to YouTube transcripts
    return await _fetchYouTubeTranscripts(songId);
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
        timeMs += 3000; // Mock timing for sequential scroll
      }
    }
    return lyricLines;
  }

  Future<List<LyricLine>> _fetchYouTubeTranscripts(String videoId) async {
    final ytClient = yt.YoutubeExplode();
    try {
      final manifest = await ytClient.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return [];

      // Try English first, otherwise take first available track
      final trackInfo = manifest.tracks.where((t) => t.language.code == 'en').firstOrNull ??
          manifest.tracks.first;

      final track = await ytClient.videos.closedCaptions.get(trackInfo);
      return track.captions.map((caption) => LyricLine(
        timeMs: caption.offset.inMilliseconds,
        text: caption.text,
      )).toList();
    } catch (_) {
      return [];
    } finally {
      ytClient.close();
    }
  }
}
