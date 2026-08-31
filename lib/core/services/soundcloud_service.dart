import 'dart:async';
import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'music_provider.dart';
import 'music_track.dart';

/// Service for searching and resolving open audio streams from SoundCloud with dynamic client ID discovery.
class SoundCloudService implements MusicProvider {
  final Dio _dio;
  final _log = AppLogger('SoundCloudService');

  String? _cachedClientId = 'Pb72ranhoyt6gw7hM7TkzUItXlMWSNSo';
  DateTime? _clientIdFetchedAt;

  SoundCloudService(this._dio);

  @override
  String get name => 'soundcloud';

  /// Obtains a live, valid SoundCloud public client ID.
  Future<String> _getClientId({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedClientId != null &&
        _clientIdFetchedAt != null &&
        DateTime.now().difference(_clientIdFetchedAt!).inHours < 12) {
      return _cachedClientId!;
    }

    try {
      _log.info('Fetching fresh SoundCloud client ID from soundcloud.com web bundle...');
      final pageRes = await _dio.get<String>('https://soundcloud.com').timeout(const Duration(seconds: 4));
      final html = pageRes.data ?? '';
      final scriptUrls = RegExp(r'<script\s+[^>]*src="(https:\/\/a-v2\.sndcdn\.com\/assets\/[^"]+\.js)"')
          .allMatches(html)
          .map((m) => m.group(1)!)
          .toList();

      for (final scriptUrl in scriptUrls.reversed) {
        try {
          final scriptRes = await _dio.get<String>(scriptUrl).timeout(const Duration(seconds: 3));
          final scriptContent = scriptRes.data ?? '';
          final match = RegExp(r'client_id[:=]"([a-zA-Z0-9]{32})"').firstMatch(scriptContent);
          if (match != null) {
            _cachedClientId = match.group(1);
            _clientIdFetchedAt = DateTime.now();
            _log.info('Obtained live SoundCloud client ID: $_cachedClientId');
            return _cachedClientId!;
          }
        } catch (_) {}
      }
    } catch (e) {
      _log.warning('Failed to dynamically extract SoundCloud client ID: $e');
    }

    return _cachedClientId ?? 'Pb72ranhoyt6gw7hM7TkzUItXlMWSNSo';
  }

  @override
  Future<List<MusicTrack>> browse(String id) => search(id);

  @override
  Future<List<MusicTrack>> search(String query, {int limit = 20}) async {
    const url = 'https://api-v2.soundcloud.com/search/tracks';
    for (int attempt = 0; attempt < 2; attempt++) {
      final clientId = await _getClientId(forceRefresh: attempt > 0);
      try {
        _log.info('Searching SoundCloud for: $query (client: $clientId)');
        final response = await _dio.get<Map<String, dynamic>>(
          url,
          queryParameters: {
            'q': query,
            'client_id': clientId,
            'limit': limit,
            'access': 'playable',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.data != null) {
          final collection = response.data!['collection'] as List<dynamic>? ?? [];
          final List<MusicTrack> tracks = [];

          for (final item in collection) {
            if (item is! Map<String, dynamic>) continue;
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'Unknown';
            final user = item['user'] as Map<String, dynamic>?;
            final artist = user?['username']?.toString() ?? 'SoundCloud Artist';
            final artworkUrl = item['artwork_url']?.toString() ?? (user?['avatar_url']?.toString() ?? '');
            final durationMs = (item['duration'] as num?)?.toInt() ?? 180000;

            final media = item['media'] as Map<String, dynamic>?;
            final transcodings = media?['transcodings'] as List<dynamic>? ?? [];
            String? streamEndpoint;

            for (final t in transcodings) {
              if (t is! Map<String, dynamic>) continue;
              final format = t['format'] as Map<String, dynamic>?;
              final protocol = format?['protocol']?.toString();
              if (protocol == 'progressive') {
                streamEndpoint = t['url']?.toString();
                break;
              }
            }

            if (streamEndpoint == null && transcodings.isNotEmpty) {
              streamEndpoint = (transcodings.first as Map<String, dynamic>?)?['url']?.toString();
            }

            if (id.isNotEmpty && title.isNotEmpty) {
              tracks.add(MusicTrack(
                id: 'sc_$id',
                title: title,
                artist: artist,
                album: 'SoundCloud Single',
                duration: Duration(milliseconds: durationMs),
                artworkUrl: artworkUrl.replaceAll('-large', '-t500x500'),
                source: 'SoundCloud',
                extras: {
                  if (streamEndpoint != null) 'streamEndpoint': streamEndpoint,
                },
              ));
            }
          }

          return tracks;
        }
      } catch (e) {
        _log.warning('SoundCloud search attempt $attempt failed: $e');
      }
    }
    return [];
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    final cleanId = trackId.startsWith('sc_') ? trackId.substring('sc_'.length) : trackId;
    final trackInfoUrl = 'https://api-v2.soundcloud.com/tracks/$cleanId';

    for (int attempt = 0; attempt < 2; attempt++) {
      final clientId = await _getClientId(forceRefresh: attempt > 0);
      try {
        _log.info('Resolving SoundCloud stream URL for track: $cleanId');
        final trackRes = await _dio.get<Map<String, dynamic>>(
          trackInfoUrl,
          queryParameters: {'client_id': clientId},
        ).timeout(const Duration(seconds: 4));

        if (trackRes.statusCode == 200 && trackRes.data != null) {
          final media = trackRes.data!['media'] as Map<String, dynamic>?;
          final transcodings = media?['transcodings'] as List<dynamic>? ?? [];
          String? streamEndpoint;

          for (final t in transcodings) {
            if (t is! Map<String, dynamic>) continue;
            final format = t['format'] as Map<String, dynamic>?;
            final protocol = format?['protocol']?.toString();
            if (protocol == 'progressive') {
              streamEndpoint = t['url']?.toString();
              break;
            }
          }

          if (streamEndpoint == null && transcodings.isNotEmpty) {
            streamEndpoint = (transcodings.first as Map<String, dynamic>?)?['url']?.toString();
          }

          if (streamEndpoint != null) {
            final mediaRes = await _dio.get<Map<String, dynamic>>(
              streamEndpoint,
              queryParameters: {'client_id': clientId},
            ).timeout(const Duration(seconds: 4));

            if (mediaRes.statusCode == 200 && mediaRes.data != null) {
              final directUrl = mediaRes.data!['url']?.toString();
              if (directUrl != null && directUrl.isNotEmpty) {
                _log.info('SoundCloud stream resolved successfully');
                return directUrl;
              }
            }
          }
        }
      } catch (e) {
        _log.warning('SoundCloud stream resolution attempt $attempt failed: $e');
      }
    }
    return null;
  }
}
