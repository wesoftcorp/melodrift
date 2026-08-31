import 'dart:math';
import '../services/music_track.dart';

/// Normalizes title by converting to lowercase and removing common video tags/descriptors.
String normalizeTitle(String title) {
  String text = title.toLowerCase();
  
  // Remove bracketed info like [Official Video], (Lyrics), etc.
  final bracketRegExp = RegExp(
    r'[\(\[][^\]\)]*(official|video|audio|lyrics|hq|hd|4k|8k|remastered|lyric|lrc|extended|edit|mix|music|studio|live|clip|clean|explicit|version|remix|theme|feat\.?|w\.?)[^\]\)]*[\)\]]',
    caseSensitive: false,
  );
  text = text.replaceAll(bracketRegExp, '');
  
  // Remove video noise keywords and phrases
  text = text.replaceAll(RegExp(r'\b(official music video|official video|official audio|lyric video|theme song|full audio song|full video song|full song|full video|latest hit song \d{4}|latest hit song|latest song \d{4}|latest song|hit song \d{4}|hit song|video song|4k|8k|hd|hq)\b', caseSensitive: false), ' ');
  
  // Remove 'feat. ...' or 'ft. ...'
  text = text.replaceAll(RegExp(r'\b(feat|ft)\.?\s+[^\-|]+', caseSensitive: false), ' ');

  // Clean special characters except alphanumeric and spaces
  text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
  
  // Collapse multiple spaces
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  return text;
}

/// Extracts clean search query from a raw YouTube title and artist.
/// E.g. "Skyfall | James Bond | Daniel Craig | 4K | Theme Song | Adele" -> "skyfall adele"
/// E.g. "Badshah Feat. Lauren Gottlieb | Official Music Video | Latest Hit Song 2017" by "Mercy" -> "mercy badshah"
String cleanYouTubeSearchQuery(String title, String artist) {
  String primaryTitle = title;
  if (title.contains('|')) {
    final parts = title.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      primaryTitle = parts.first;
      for (final p in parts.skip(1)) {
        final normP = p.toLowerCase();
        if (!normP.contains('4k') && !normP.contains('video') && !normP.contains('theme') && !normP.contains('official') && !normP.contains('latest') && !normP.contains('song') && p.length < 30) {
          primaryTitle = '$primaryTitle $p';
          break;
        }
      }
    }
  }

  final cleanT = normalizeTitle(primaryTitle);
  final cleanA = normalizeTitle(artist.split('•').first.split(',').first.split('&').first);

  if (cleanA.isNotEmpty && !cleanT.contains(cleanA) && !cleanA.contains('topic') && !cleanA.contains('vevo') && !cleanA.contains('virus')) {
    return '$cleanA $cleanT'.trim();
  }
  return cleanT;
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
/// Allows generous duration difference for music videos with intros/outros.
/// Uses a weighted similarity score (75% Title, 25% Artist).
MusicTrack? findMatchingSaavnTrack(MusicTrack ytTrack, List<MusicTrack> saavnTracks, {double threshold = 0.55}) {
  MusicTrack? bestMatch;
  double highestScore = 0.0;

  final normYtTitle = normalizeTitle(ytTrack.title);
  final normYtArtist = normalizeTitle(ytTrack.artist);

  for (final candidate in saavnTracks) {
    final normCandTitle = normalizeTitle(candidate.title);
    final normCandArtist = normalizeTitle(candidate.artist);

    final titleSim = calculateSimilarity(normYtTitle, normCandTitle);
    final artistSim = calculateSimilarity(normYtArtist, normCandArtist);

    // Title match contains or prefix bonus
    double effectiveTitleSim = titleSim;
    if (normCandTitle.contains(normYtTitle) || normYtTitle.contains(normCandTitle) || (normCandTitle.length > 3 && normYtTitle.startsWith(normCandTitle))) {
      effectiveTitleSim = max(effectiveTitleSim, 0.85);
    }

    // Weighted average: 75% title, 25% artist
    double totalSim = (effectiveTitleSim * 0.75) + (artistSim * 0.25);

    // Duration check: if duration exists, apply gentle adjustment rather than hard rejection
    if (ytTrack.duration != Duration.zero && candidate.duration != Duration.zero) {
      final timeDiff = (ytTrack.duration.inSeconds - candidate.duration.inSeconds).abs();
      if (timeDiff <= 10) {
        totalSim += 0.1; // exact match bonus
      } else if (timeDiff > 60) {
        continue; // reject if massive time difference
      }

    }

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
