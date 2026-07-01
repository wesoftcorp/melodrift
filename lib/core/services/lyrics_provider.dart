import '../../domain/entities/lyrics.dart';

abstract class LyricsProvider {
  String get name;
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration);
}
