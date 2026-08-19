import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class LyricsRegistry {
  final List<LyricsProvider> _providers;
  final _log = AppLogger('LyricsRegistry');

  LyricsRegistry(this._providers);

  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    _log.info('LyricsRegistry attempting parallel fetch for: $title - $artist');
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

      for (final lyrics in results) {
        if (lyrics.isNotEmpty) {
          return lyrics;
        }
      }
    } catch (e, s) {
      _log.error('LyricsRegistry error: $e', e, s);
    }

    _log.warning('LyricsRegistry: All lyrics providers failed for: $title - $artist');
    return [];
  }
}

