import 'dart:math';
import '../services/music_track.dart';

/// Normalizes title by converting to lowercase and removing common video tags/descriptors.
String normalizeTitle(String title) {
  String text = title.toLowerCase();
  
  // Remove bracketed info like [Official Video], (Lyrics), etc.
  final bracketRegExp = RegExp(
    r'[\(\[][^\]\)]*(official|video|audio|lyrics|hq|hd|remastered|lyric|lrc|extended|edit|mix|music|studio|live|clip|clean|explicit|version|remix|feat\.?|w\.?)[^\]\)]*[\)\]]',
    caseSensitive: false,
  );
  text = text.replaceAll(bracketRegExp, '');
  
  // Clean special characters except alphanumeric and spaces
  text = text.replaceAll(RegExp(r'[^\w\s]'), '');
  
  // Collapse multiple spaces
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  return text;
}

/// Computes Levenshtein distance between two strings.
int levenshteinDistance(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  final List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
  final List<int> v1 = List<int>.filled(t.length + 1, 0);

  for (int i = 0; i < s.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < t.length; j++) {
      final int cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
    }
    for (int j = 0; j < v0.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v0[t.length];
}

int _min3(int a, int b, int c) {
  int min = a;
  if (b < min) min = b;
  if (c < min) min = c;
  return min;
}

/// Calculates similarity score between 0.0 and 1.0.
double calculateSimilarity(String s1, String s2) {
  if (s1.isEmpty && s2.isEmpty) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;
  
  final dist = levenshteinDistance(s1, s2);
  final maxLen = max(s1.length, s2.length);
  return 1.0 - (dist / maxLen);
}

/// Finds the best matching JioSaavn track for a YouTube track.
/// Enforces a hard ±5 seconds duration filter gate.
/// Uses a weighted similarity score (70% Title, 30% Artist).
MusicTrack? findMatchingSaavnTrack(MusicTrack ytTrack, List<MusicTrack> saavnTracks, {double threshold = 0.75}) {
  MusicTrack? bestMatch;
  double highestScore = 0.0;

  final normYtTitle = normalizeTitle(ytTrack.title);
  final normYtArtist = normalizeTitle(ytTrack.artist);

  for (final candidate in saavnTracks) {
    // 1. Duration check: ±5s margin (skip if duration is zero/unknown on either side)
    if (ytTrack.duration != Duration.zero && candidate.duration != Duration.zero) {
      final timeDiff = (ytTrack.duration.inSeconds - candidate.duration.inSeconds).abs();
      if (timeDiff > 5) continue;
    }


    // 2. Similarity check
    final normCandTitle = normalizeTitle(candidate.title);
    final normCandArtist = normalizeTitle(candidate.artist);

    final titleSim = calculateSimilarity(normYtTitle, normCandTitle);
    final artistSim = calculateSimilarity(normYtArtist, normCandArtist);

    // Weighted average: 70% title, 30% artist
    final double totalSim = (titleSim * 0.7) + (artistSim * 0.3);

    if (totalSim > highestScore) {
      highestScore = totalSim;
      bestMatch = candidate;
    }
  }

  if (highestScore >= threshold) {
    return bestMatch;
  }
  return null;
}
