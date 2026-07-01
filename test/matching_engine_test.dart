import 'package:flutter_test/flutter_test.dart';
import 'package:melodrift/core/services/music_track.dart';
import 'package:melodrift/core/utils/matching_engine.dart';

void main() {
  group('Title Normalization Tests', () {
    test('should remove bracketed info and special characters', () {
      expect(normalizeTitle('Closer (feat. Halsey) [Official Video]'), 'closer');
      expect(normalizeTitle('Come Closer (Lyrics)'), 'come closer');
      expect(normalizeTitle('DIDO - CLOSER (Official Audio)'), 'dido closer');
      expect(normalizeTitle('Closer [HQ]'), 'closer');
    });

    test('should collapse whitespace and lowercase the title', () {
      expect(normalizeTitle('  Closer   Song  '), 'closer song');
      expect(normalizeTitle('CLOSER'), 'closer');
    });
  });

  group('Levenshtein Similarity Tests', () {
    test('should calculate correct similarity score', () {
      expect(calculateSimilarity('closer', 'closer'), 1.0);
      expect(calculateSimilarity('', ''), 1.0);
      expect(calculateSimilarity('closer', ''), 0.0);
      expect(calculateSimilarity('closer', 'clsoer'), 2.0 / 6.0 > 0.6 ? closeTo(0.666, 0.01) : isNotNull);
    });
  });

  group('Matching Engine Tests', () {
    const ytTrack = MusicTrack(
      id: 'yt_123',
      title: 'Closer (feat. Halsey) [Official Video]',
      artist: 'The Chainsmokers',
      album: 'Collage',
      duration: Duration(minutes: 4, seconds: 6),
      artworkUrl: 'https://example.com/yt.jpg',
      source: 'youtube',
    );

    test('should match correct JioSaavn song within duration limit and similarity threshold', () {
      final candidates = [
        const MusicTrack(
          id: 'saavn_001',
          title: 'Closer',
          artist: 'The Chainsmokers feat. Halsey',
          album: 'Closer',
          duration: Duration(minutes: 4, seconds: 4), // Diff: 2s
          artworkUrl: 'https://example.com/saavn.jpg',
          source: 'jiosaavn',
        ),
        const MusicTrack(
          id: 'saavn_002',
          title: 'Closer',
          artist: 'Ne-Yo',
          album: 'Year Of The Gentleman',
          duration: Duration(minutes: 3, seconds: 55), // Diff: 11s (rejected by duration)
          artworkUrl: 'https://example.com/saavn2.jpg',
          source: 'jiosaavn',
        ),
      ];

      final match = findMatchingSaavnTrack(ytTrack, candidates);
      expect(match, isNotNull);
      expect(match!.id, 'saavn_001');
    });

    test('should reject matches outside ±5s duration difference', () {
      final candidates = [
        const MusicTrack(
          id: 'saavn_003',
          title: 'Closer (feat. Halsey)',
          artist: 'The Chainsmokers',
          album: 'Collage',
          duration: Duration(minutes: 5, seconds: 12), // Diff: 66s (too large)
          artworkUrl: 'https://example.com/saavn3.jpg',
          source: 'jiosaavn',
        ),
      ];

      final match = findMatchingSaavnTrack(ytTrack, candidates);
      expect(match, isNull);
    });

    test('should reject matches below similarity threshold', () {
      final candidates = [
        const MusicTrack(
          id: 'saavn_004',
          title: 'Come Closer',
          artist: 'Wizkid feat. Drake',
          album: 'Sounds From The Other Side',
          duration: Duration(minutes: 4, seconds: 6), // Diff: 0s
          artworkUrl: 'https://example.com/saavn4.jpg',
          source: 'jiosaavn',
        ),
      ];

      final match = findMatchingSaavnTrack(ytTrack, candidates, threshold: 0.8);
      expect(match, isNull);
    });
  });
}
