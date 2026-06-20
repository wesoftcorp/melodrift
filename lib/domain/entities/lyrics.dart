class LyricWord {
  final int startMs;
  final int endMs;
  final String text;

  const LyricWord({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

class LyricLine {
  final int timeMs;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.timeMs,
    required this.text,
    this.words = const [],
  });
}
