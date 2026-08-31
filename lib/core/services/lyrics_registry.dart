import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class LyricsRegistry {
  final List<LyricsProvider> _providers;
  final _log = AppLogger('LyricsRegistry');

  LyricsRegistry(this._providers);

  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    _log.info('LyricsRegistry attempting parallel fetch for: "$title" - "$artist"');
    try {
      final results = await Future.wait(
        _providers.map((provider) async {
          try {
            final lyrics = await provider.getLyrics(title, artist, duration);
            if (lyrics.isNotEmpty) {
              _log.info('LyricsProvider ${provider.name} returned ${lyrics.length} lines');
            }
            return lyrics;
          } catch (e) {
            _log.warning('LyricsProvider ${provider.name} failed with error: $e');
            return <LyricLine>[];
          }
        }),
      );

      // 1. First pass: Find genuinely synced lyrics (real LRC timestamps)
      for (final lyrics in results) {
        if (lyrics.isNotEmpty && _isGenuinelySynced(lyrics)) {
          _log.info('Selected genuinely synced lyrics (${lyrics.length} lines)');
          return lyrics;
        }
      }

      // 2. Second pass: Fall back to unsynced/plain lyrics
      for (final lyrics in results) {
        if (lyrics.isNotEmpty) {
          _log.info('Falling back to plain/semi-synced lyrics (${lyrics.length} lines)');
          return lyrics;
        }
      }
    } catch (e, s) {
      _log.error('LyricsRegistry error: $e', e, s);
    }

    _log.warning('LyricsRegistry: All lyrics providers failed for: $title - $artist');
    return [];
  }

  bool _isGenuinelySynced(List<LyricLine> lyrics) {
    if (lyrics.length < 2) return false;
    // Check if timestamps are not just fake fixed 3000/3500 intervals starting from 0
    if (lyrics.first.timeMs == 0 && lyrics.length > 3) {
      final diff1 = lyrics[1].timeMs - lyrics[0].timeMs;
      final diff2 = lyrics[2].timeMs - lyrics[1].timeMs;
      final diff3 = lyrics[3].timeMs - lyrics[2].timeMs;
      if ((diff1 == 3000 || diff1 == 3500) && diff1 == diff2 && diff2 == diff3) {
        return false; // synthetic fallback timestamps
      }
    }
    return true;
  }
}

