import 'dart:async';
import '../utils/logger.dart';
import '../utils/matching_engine.dart';
import '../../domain/entities/song.dart';
import 'music_track.dart';
import 'jiosaavn_service.dart';
import 'soundcloud_service.dart';

/// Unified resolution result containing stream URL and matched source metadata.
class ResolvedStreamResult {
  final String url;
  final String source;
  final int? bitrate;
  final bool isSaavnMatch;

  const ResolvedStreamResult({
    required this.url,
    required this.source,
    this.bitrate,
    this.isSaavnMatch = false,
  });
}

/// In-memory cache entry with expiration.
class _StreamCacheEntry {
  final ResolvedStreamResult result;
  final DateTime expiresAt;
  _StreamCacheEntry(this.result, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Centralized audio resolution engine.
///
/// Multi-Tier Open Architecture:
/// - Tier 1: Direct JioSaavn CDN (320kbps Studio Master)
/// - Tier 2: Direct SoundCloud CDN (Progressive MP3/AAC)
/// - Tier 3: High-Quality JioSaavn / SoundCloud Song Matcher
class UnifiedStreamResolver {
  final JioSaavnService _jioSaavn;
  final SoundCloudService _soundCloud;
  final _log = AppLogger('UnifiedStreamResolver');

  final Map<String, _StreamCacheEntry> _cache = {};
  static const _cacheTtl = Duration(hours: 4);

  UnifiedStreamResolver(this._jioSaavn, this._soundCloud);

  /// Resolves the playable stream URL using the multi-tier strategy.
  Future<ResolvedStreamResult?> resolve({
    Song? song,
    String? videoId,
    String quality = 'High',
  }) async {
    final String targetId = (song?.videoId != null && song!.videoId.isNotEmpty)
        ? song.videoId
        : (videoId ?? (song?.id ?? ''));

    if (targetId.isEmpty) {
      _log.error('Cannot resolve stream: No valid target ID or song provided.');
      return null;
    }

    final cacheKey = '$targetId:$quality';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isValid) {
      _log.debug('Cache hit for $targetId (${cached.result.source})');
      return cached.result;
    }

    final isJioSaavn = (song != null && (song.source.toLowerCase().contains('jiosaavn') || song.id.startsWith('jiosaavn_'))) ||
        targetId.startsWith('jiosaavn_') ||
        (song != null && song.source == 'JioSaavn');

    final isSoundCloud = targetId.startsWith('sc_') || (song != null && song.source.toLowerCase().contains('soundcloud'));

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 1: Direct JioSaavn Track (320kbps CD Quality)
    // ──────────────────────────────────────────────────────────────────────────
    if (isJioSaavn) {
      try {
        _log.info('Fetching direct JioSaavn stream for $targetId');
        final url = await _jioSaavn.getStreamUrl(targetId).timeout(const Duration(seconds: 8));

        if (url != null && url.isNotEmpty) {
          final res = ResolvedStreamResult(url: url, source: 'JioSaavn 320kbps', bitrate: 320);
          _cacheResult(cacheKey, res);
          return res;
        }
      } catch (e) {
        _log.error('Direct JioSaavn resolution failed for $targetId: $e');
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 2: Direct SoundCloud Track (Progressive MP3/AAC)
    // ──────────────────────────────────────────────────────────────────────────
    if (isSoundCloud) {
      try {
        _log.info('Fetching direct SoundCloud stream for $targetId');
        final url = await _soundCloud.getStreamUrl(targetId).timeout(const Duration(seconds: 5));
        if (url != null && url.isNotEmpty) {
          final res = ResolvedStreamResult(url: url, source: 'SoundCloud Stream', bitrate: 160);
          _cacheResult(cacheKey, res);
          return res;
        }
      } catch (e) {
        _log.error('Direct SoundCloud resolution failed for $targetId: $e');
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 3: Universal JioSaavn & SoundCloud Matcher for Metadata Tracks
    // ──────────────────────────────────────────────────────────────────────────
    if (song != null) {
      try {
        final cleanQuery = cleanYouTubeSearchQuery(song.title, song.artist);
        final cleanTitle = normalizeTitle(song.title);
        final searchQuery = cleanQuery.isNotEmpty ? cleanQuery : cleanTitle;

        if (searchQuery.isNotEmpty) {
          _log.info('Attempting JioSaavn 320kbps match for "$searchQuery"');
          final saavnCandidates = await _jioSaavn
              .search(searchQuery, limit: 20)
              .timeout(const Duration(seconds: 4), onTimeout: () => []);

          if (saavnCandidates.isNotEmpty) {
            final trackObj = MusicTrack(
              id: targetId,
              title: song.title,
              artist: song.artist,
              album: song.album,
              duration: song.duration,
              artworkUrl: song.artworkUrl,
              source: song.source,
            );
            final match = findMatchingSaavnTrack(trackObj, saavnCandidates, threshold: 0.50);
            if (match != null) {
              final directStreamUrl = match.extras['streamUrl'] as String?;
              final saavnUrl = (directStreamUrl != null && directStreamUrl.isNotEmpty)
                  ? directStreamUrl
                  : await _jioSaavn.getStreamUrl(match.id).timeout(const Duration(seconds: 4));
              if (saavnUrl != null && saavnUrl.isNotEmpty) {
                _log.info('Tier 3 SUCCESS: Matched JioSaavn 320kbps CDN for "${song.title}"');
                final res = ResolvedStreamResult(
                  url: saavnUrl,
                  source: 'JioSaavn Matcher (320kbps)',
                  bitrate: 320,
                  isSaavnMatch: true,
                );
                _cacheResult(cacheKey, res);
                return res;
              }
            }
          }

          // Fallback to SoundCloud search
          _log.info('Attempting SoundCloud match for "$searchQuery"');
          final scCandidates = await _soundCloud.search(searchQuery, limit: 10).timeout(const Duration(seconds: 4), onTimeout: () => []);
          if (scCandidates.isNotEmpty) {
            final scTrack = scCandidates.first;
            final scUrl = await _soundCloud.getStreamUrl(scTrack.id).timeout(const Duration(seconds: 4));
            if (scUrl != null && scUrl.isNotEmpty) {
              _log.info('Tier 3 SUCCESS: Matched SoundCloud stream for "${song.title}"');
              final res = ResolvedStreamResult(
                url: scUrl,
                source: 'SoundCloud Stream',
                bitrate: 160,
              );
              _cacheResult(cacheKey, res);
              return res;
            }
          }
        }
      } catch (e) {
        _log.debug('Tier 3 stream matching skipped or failed: $e');
      }
    }

    _log.error('All resolution tiers failed for track: $targetId');
    return null;
  }

  void _cacheResult(String key, ResolvedStreamResult result) {
    _cache[key] = _StreamCacheEntry(result, DateTime.now().add(_cacheTtl));
  }

  void dispose() {}
}
