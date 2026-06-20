import '../entities/lyrics.dart';

abstract class LyricsRepository {
  /// Fetch synced/karaoke or plain lyrics for a song.
  /// Falls back to YouTube transcripts if LRCLIB does not have it.
  Future<List<LyricLine>> getLyrics(
    String songId,
    String title,
    String artist,
    Duration duration,
  );
}
