import '../../domain/entities/lyrics.dart';
import '../utils/logger.dart';
import 'lyrics_provider.dart';

class LyricsRegistry {
  final List<LyricsProvider> _providers;
  final _log = AppLogger('LyricsRegistry');

  LyricsRegistry(this._providers);

  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    for (final provider in _providers) {
      try {
        _log.info('LyricsRegistry attempting provider: ${provider.name}');
        final lyrics = await provider.getLyrics(title, artist, duration);
        if (lyrics.isNotEmpty) {
          _log.info('LyricsRegistry successfully retrieved lyrics from provider: ${provider.name}');
          return lyrics;
        }
      } catch (e, s) {
        _log.error('LyricsRegistry provider ${provider.name} failed with error: $e', e, s);
      }
    }
    _log.warning('LyricsRegistry: All lyrics providers failed to resolve lyrics for: $title - $artist');
    return [];
  }
}
