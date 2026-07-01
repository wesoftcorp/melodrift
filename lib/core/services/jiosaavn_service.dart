import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'music_provider.dart';
import 'music_track.dart';

class JioSaavnService implements MusicProvider {
  final Dio _dio;
  final _log = AppLogger('JioSaavnService');
  final String _baseUrl;

  JioSaavnService(this._dio, {String baseUrl = 'https://jiosaavn.softcorpllc.workers.dev'}) : _baseUrl = baseUrl;


  @override
  String get name => 'jiosaavn';

  @override
  Future<List<MusicTrack>> search(String query) async {
    final url = '$_baseUrl/api/search/songs';
    try {
      _log.info('Searching JioSaavn for: $query');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'query': query},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 || response.data == null) {
        _log.error('JioSaavn search returned status code: ${response.statusCode}');
        return [];
      }

      final body = response.data!;
      final success = body['success'] as bool? ?? false;
      if (!success) {
        _log.warning('JioSaavn search reported success=false');
        return [];
      }

      final dataMap = body['data'] as Map<String, dynamic>?;
      if (dataMap == null) return [];

      final results = dataMap['results'] as List<dynamic>? ?? [];
      final List<MusicTrack> tracks = [];

      for (final result in results) {
        final item = result as Map<String, dynamic>?;
        if (item == null) continue;

        try {
          final id = item['id'] as String?;
          final title = item['name'] as String? ?? item['title'] as String? ?? 'Unknown';
          if (id == null) continue;

          // Parse Artists: can be primaryArtists string or list inside artists
          String artist = 'Unknown';
          if (item['primaryArtists'] != null) {
            artist = item['primaryArtists'].toString();
          } else if (item['artists'] is Map) {
            final artistsMap = item['artists'] as Map;
            final primaryList = artistsMap['primary'] as List<dynamic>?;
            if (primaryList != null && primaryList.isNotEmpty) {
              artist = primaryList
                  .map((a) => ((a as Map)['name'] ?? '').toString())
                  .where((name) => name.isNotEmpty)
                  .join(', ');
            }
          }

          // Parse Album
          String album = 'Unknown';
          if (item['album'] is Map) {
            album = (item['album'] as Map)['name'] as String? ?? 'Unknown';
          } else if (item['album'] != null) {
            album = item['album'].toString();
          }

          // Parse Duration
          Duration duration = Duration.zero;
          final durationVal = item['duration'];
          if (durationVal != null) {
            final seconds = int.tryParse(durationVal.toString());
            if (seconds != null) {
              duration = Duration(seconds: seconds);
            }
          }

          // Parse Artwork URL
          String artworkUrl = '';
          final imageVal = item['image'];
          if (imageVal is List) {
            if (imageVal.isNotEmpty) {
              final lastImg = imageVal.last as Map<String, dynamic>?;
              artworkUrl = lastImg?['link'] as String? ?? lastImg?['url'] as String? ?? '';
            }
          } else if (imageVal is String) {
            artworkUrl = imageVal;
          }

          tracks.add(MusicTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkUrl: artworkUrl,
            source: 'jiosaavn',
            extras: {
              'id': id,
            },
          ));
        } catch (e) {
          _log.warning('Failed to parse JioSaavn search result item: $e');
        }
      }

      return tracks;
    } catch (e, s) {
      _log.error('JioSaavn search failed: $e', e, s);
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    final cleanId = trackId.startsWith('jiosaavn_') ? trackId.substring('jiosaavn_'.length) : trackId;
    final url = '$_baseUrl/api/songs';
    try {
      _log.info('Fetching JioSaavn stream URL for track: $cleanId');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'ids': cleanId},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || response.data == null) {
        _log.error('JioSaavn song details returned status code: ${response.statusCode}');
        return null;
      }

      final body = response.data!;
      final success = body['success'] as bool? ?? false;
      if (!success) {
        _log.warning('JioSaavn song details reported success=false');
        return null;
      }

      final dataList = body['data'] as List<dynamic>?;
      if (dataList == null || dataList.isEmpty) return null;

      final songData = dataList.first as Map<String, dynamic>?;
      if (songData == null) return null;

      final downloadUrlsRaw = songData['downloadUrl'] as List<dynamic>? ?? [];
      if (downloadUrlsRaw.isEmpty) return null;

      final downloadUrls = downloadUrlsRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Extract 320kbps quality if available, otherwise fall back to highest
      final urlObj = downloadUrls.firstWhere(
        (e) => e['quality'] == '320kbps',
        orElse: () => downloadUrls.last,
      );

      return urlObj['link'] as String? ?? urlObj['url'] as String?;
    } catch (e, s) {
      _log.error('Failed to get JioSaavn stream URL: $e', e, s);
      return null;
    }
  }

  @override
  Future<List<MusicTrack>> browse(String browseId) async {
    // Try Album endpoint first
    final List<MusicTrack> tracks = await _browseEndpoint('$_baseUrl/api/albums', browseId);
    if (tracks.isNotEmpty) return tracks;

    // Try Playlist endpoint next
    return await _browseEndpoint('$_baseUrl/api/playlists', browseId);
  }

  Future<List<MusicTrack>> _browseEndpoint(String url, String id) async {
    try {
      _log.info('Browsing JioSaavn endpoint $url for id: $id');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'id': id},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final body = response.data!;
      final success = body['success'] as bool? ?? false;
      if (!success) return [];

      final dataMap = body['data'] as Map<String, dynamic>?;
      if (dataMap == null) return [];

      final songs = dataMap['songs'] as List<dynamic>? ?? [];
      final List<MusicTrack> tracks = [];

      for (final song in songs) {
        final item = song as Map<String, dynamic>?;
        if (item == null) continue;

        try {
          final id = item['id'] as String?;
          final title = item['name'] as String? ?? item['title'] as String? ?? 'Unknown';
          if (id == null) continue;

          String artist = 'Unknown';
          if (item['primaryArtists'] != null) {
            artist = item['primaryArtists'].toString();
          } else if (item['artists'] is Map) {
            final artistsMap = item['artists'] as Map;
            final primaryList = artistsMap['primary'] as List<dynamic>?;
            if (primaryList != null && primaryList.isNotEmpty) {
              artist = primaryList
                  .map((a) => ((a as Map)['name'] ?? '').toString())
                  .where((name) => name.isNotEmpty)
                  .join(', ');
            }
          }

          String album = 'Unknown';
          if (item['album'] is Map) {
            album = (item['album'] as Map)['name'] as String? ?? 'Unknown';
          } else if (item['album'] != null) {
            album = item['album'].toString();
          }

          Duration duration = Duration.zero;
          final durationVal = item['duration'];
          if (durationVal != null) {
            final seconds = int.tryParse(durationVal.toString());
            if (seconds != null) {
              duration = Duration(seconds: seconds);
            }
          }

          String artworkUrl = '';
          final imageVal = item['image'];
          if (imageVal is List) {
            if (imageVal.isNotEmpty) {
              final lastImg = imageVal.last as Map<String, dynamic>?;
              artworkUrl = lastImg?['link'] as String? ?? lastImg?['url'] as String? ?? '';
            }
          } else if (imageVal is String) {
            artworkUrl = imageVal;
          }

          tracks.add(MusicTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkUrl: artworkUrl,
            source: 'jiosaavn',
            extras: {
              'id': id,
            },
          ));
        } catch (e) {
          _log.warning('Failed to parse JioSaavn browse song: $e');
        }
      }
      return tracks;
    } catch (e) {
      _log.warning('JioSaavn browse endpoint failed: $e');
      return [];
    }
  }
}
