import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../domain/entities/lyrics.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/lyrics_registry.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10), // large files need time
      sendTimeout: const Duration(seconds: 30),
    ),
  );
});

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepositoryImpl();
});

class LyricsRepositoryImpl implements LyricsRepository {
  LyricsRepositoryImpl();

  @override
  Future<List<LyricLine>> getLyrics(
    String songId,
    String title,
    String artist,
    Duration duration,
  ) async {
    // Try the LyricsRegistry first (LRCLib -> YouLyPlus -> KuGou)
    try {
      final lyrics = await getIt<LyricsRegistry>().getLyrics(title, artist, duration);
      if (lyrics.isNotEmpty) {
        return lyrics;
      }
    } catch (_) {
      // Fallback if registry failed entirely
    }

    // Fallback to YouTube transcripts
    return await _fetchYouTubeTranscripts(songId);
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
