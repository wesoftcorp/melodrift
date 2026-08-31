import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lyrics.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/lyrics_registry.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
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
    // Try the LyricsRegistry (JioSaavn -> LRCLib -> YouLyPlus -> KuGou)
    try {
      final lyrics = await getIt<LyricsRegistry>().getLyrics(title, artist, duration);
      if (lyrics.isNotEmpty) {
        return lyrics;
      }
    } catch (_) {}

    return const [];
  }
}
