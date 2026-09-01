import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'music_provider.dart';
import 'music_track.dart';

class JioSaavnService implements MusicProvider {
  final Dio _dio;
  final _log = AppLogger('JioSaavnService');
  final String _baseUrl;

  JioSaavnService(this._dio, {String baseUrl = 'https://jiosaavn.softcorpllc.workers.dev'}) : _baseUrl = baseUrl;

  Future<String> _getEffectiveBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var customUrl = prefs.getString('custom_jiosaavn_api_url') ?? '';
      if (customUrl.isNotEmpty) {
        customUrl = customUrl.trim();
        if (!customUrl.startsWith('http://') && !customUrl.startsWith('https://')) {
          customUrl = 'https://$customUrl';
        }
        return customUrl.endsWith('/') ? customUrl.substring(0, customUrl.length - 1) : customUrl;
      }
    } catch (_) {}
    return _baseUrl;
  }

  @override
  String get name => 'jiosaavn';

  List<MusicTrack> _parseSearchResponse(Response<Map<String, dynamic>> response) {
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
        _log.warning('Failed to parse JioSaavn search result item: $e');
      }
    }
    return tracks;
  }

  @override
  Future<List<MusicTrack>> search(String query, {int limit = 50}) async {
    final baseUrl = await _getEffectiveBaseUrl();
    final url = '$baseUrl/api/search/songs';
    try {
      _log.info('Searching JioSaavn for: $query (limit $limit)');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'query': query, 'limit': limit},
      ).timeout(const Duration(seconds: 8));

      return _parseSearchResponse(response);
    } catch (e) {
      // 1. If custom/primary base URL failed or timed out, try official direct JioSaavn API
      try {
        _log.info('Falling back to official direct JioSaavn API for: $query');
        final directResponse = await _dio.get<dynamic>(
          'https://www.jiosaavn.com/api.php',
          queryParameters: {
            '__call': 'search.getResults',
            '_format': 'json',
            '_marker': '0',
            'api_version': '4',
            'ctx': 'web6dot0',
            'n': limit > 50 ? 50 : limit,
            'p': '1',
            'q': query,
          },
        ).timeout(const Duration(seconds: 6));

        if (directResponse.statusCode == 200 && directResponse.data != null) {
          final data = directResponse.data;
          List<dynamic>? list;
          if (data is Map) {
            if (data['results'] is List) {
              list = data['results'] as List;
            } else if (data['songs'] is Map && data['songs']['data'] is List) {
              list = data['songs']['data'] as List;
            } else if (data['data'] is Map && data['data']['results'] is List) {
              list = data['data']['results'] as List;
            }
          }
          if (list != null && list.isNotEmpty) {
            final List<MusicTrack> directTracks = [];
            for (final item in list) {
              if (item is! Map) continue;
              final id = item['id']?.toString() ?? '';
              final title = item['title']?.toString() ?? item['song']?.toString() ?? item['name']?.toString() ?? '';
              final image = item['image']?.toString() ?? '';
              final artworkUrl = image.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');

              String artist = item['primary_artists']?.toString() ?? item['singers']?.toString() ?? '';
              if (artist.isEmpty && item['more_info'] != null) {
                final moreInfo = item['more_info'];
                if (moreInfo is Map) {
                  artist = moreInfo['primary_artists']?.toString() ?? moreInfo['singers']?.toString() ?? '';
                }
              }
              if (artist.isEmpty && item['description'] != null) {
                final desc = item['description'].toString();
                final parts = desc.split('·');
                artist = parts.length > 1 ? parts[1].trim() : desc.trim();
              }

              String album = item['album']?.toString() ?? '';
              if (album.isEmpty && item['more_info'] != null && item['more_info'] is Map) {
                album = item['more_info']['album']?.toString() ?? '';
              }
              if (album.isEmpty) album = 'JioSaavn Single';

              Duration duration = const Duration(minutes: 3, seconds: 30);
              final durVal = item['duration'] ?? (item['more_info'] is Map ? item['more_info']['duration'] : null);
              if (durVal != null) {
                final sec = int.tryParse(durVal.toString());
                if (sec != null && sec > 0) duration = Duration(seconds: sec);
              }

              if (id.isNotEmpty && title.isNotEmpty) {
                directTracks.add(MusicTrack(
                  id: id,
                  title: title,
                  artist: artist.isNotEmpty ? artist : 'Unknown Artist',
                  album: album,
                  duration: duration,
                  artworkUrl: artworkUrl,
                  source: 'jiosaavn',
                ));
              }
            }
            if (directTracks.isNotEmpty) return directTracks;
          }
        }
      } catch (e2) {
        _log.error('Official direct JioSaavn fallback failed: $e2');
      }

      return [];
    }
  }





  Future<String?> _parseStreamUrlResponse(Response<Map<String, dynamic>> response) async {
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

    String targetQuality = '320kbps';
    try {
      final prefs = await SharedPreferences.getInstance();
      final qualityIdx = prefs.getInt('streaming_quality') ?? 3;
      if (qualityIdx == 1) {
        targetQuality = '96kbps';
      } else if (qualityIdx == 2) {
        targetQuality = '160kbps';
      }
    } catch (_) {}

    // Extract preferred quality if available, otherwise fall back to 320kbps / highest
    final urlObj = downloadUrls.firstWhere(
      (e) => e['quality'] == targetQuality,
      orElse: () => downloadUrls.firstWhere(
        (e) => e['quality'] == '320kbps',
        orElse: () => downloadUrls.last,
      ),
    );

    return urlObj['link'] as String? ?? urlObj['url'] as String?;
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    final cleanId = trackId.startsWith('jiosaavn_') ? trackId.substring('jiosaavn_'.length) : trackId;
    final baseUrl = await _getEffectiveBaseUrl();
    final url = '$baseUrl/api/songs';
    try {
      _log.info('Fetching JioSaavn stream URL for track: $cleanId');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'ids': cleanId},
      ).timeout(const Duration(seconds: 15));

      return await _parseStreamUrlResponse(response);
    } catch (e, s) {

      _log.error('Failed to get JioSaavn stream URL: $e', e, s);
      if (baseUrl != _baseUrl) {
        try {
          _log.info('Falling back to default JioSaavn base URL for stream URL: $_baseUrl');
          final response = await _dio.get<Map<String, dynamic>>(
            '$_baseUrl/api/songs',
            queryParameters: {'ids': cleanId},
          ).timeout(const Duration(seconds: 15));
          return _parseStreamUrlResponse(response);
        } catch (e2) {
          _log.error('JioSaavn stream URL fallback failed: $e2');
        }
      }
      return null;
    }
  }

  @override
  Future<List<MusicTrack>> browse(String browseId) async {
    final baseUrl = await _getEffectiveBaseUrl();
    // Try Album endpoint first
    final List<MusicTrack> tracks = await _browseEndpoint('$baseUrl/api/albums', browseId);
    if (tracks.isNotEmpty) return tracks;

    // Try Playlist endpoint next
    return await _browseEndpoint('$baseUrl/api/playlists', browseId);
  }

  List<MusicTrack> _parseBrowseResponse(dynamic responseData) {
    if (responseData == null) return [];

    List<dynamic> songs = [];
    if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is Map) {
        final dataMap = responseData['data'] as Map<String, dynamic>;
        if (dataMap['songs'] is List) {
          songs = dataMap['songs'] as List;
        } else if (dataMap['list'] is List) {
          songs = dataMap['list'] as List;
        }
      } else if (responseData['list'] is List) {
        songs = responseData['list'] as List;
      } else if (responseData['songs'] is List) {
        songs = responseData['songs'] as List;
      } else if (responseData['results'] is List) {
        songs = responseData['results'] as List;
      }
    }

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
        } else if (item['subtitle'] != null && item['subtitle'].toString().isNotEmpty) {
          final sub = item['subtitle'].toString();
          // Subtitle often has "Artist1, Artist2 - Album"
          artist = sub.contains(' - ') ? sub.split(' - ').first.trim() : sub.trim();
        } else if (item['artists'] is Map) {
          final artistsMap = item['artists'] as Map;
          final primaryList = artistsMap['primary'] as List<dynamic>?;
          if (primaryList != null && primaryList.isNotEmpty) {
            artist = primaryList
                .map((a) => ((a as Map)['name'] ?? '').toString())
                .where((name) => name.isNotEmpty)
                .join(', ');
          }
        } else if (item['more_info'] is Map) {
          final moreInfo = item['more_info'] as Map;
          if (moreInfo['music'] != null && moreInfo['music'].toString().isNotEmpty) {
            artist = moreInfo['music'].toString();
          } else if (moreInfo['artistMap'] is Map) {
            final artistMap = moreInfo['artistMap'] as Map;
            final primaryArtists = artistMap['primary_artists'] as List<dynamic>?;
            if (primaryArtists != null && primaryArtists.isNotEmpty) {
              artist = primaryArtists
                  .map((a) => ((a as Map)['name'] ?? '').toString())
                  .where((name) => name.isNotEmpty)
                  .join(', ');
            }
          }
        }

        String album = 'Unknown';
        if (item['album'] is Map) {
          album = (item['album'] as Map)['name'] as String? ?? 'Unknown';
        } else if (item['album'] != null) {
          album = item['album'].toString();
        } else if (item['more_info'] is Map && item['more_info']['album'] != null) {
          album = item['more_info']['album'].toString();
        }

        Duration duration = Duration.zero;
        final durationVal = item['duration'] ?? (item['more_info'] is Map ? item['more_info']['duration'] : null);
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
        artworkUrl = artworkUrl.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');

        final Map<String, dynamic> extras = {'id': id};
        if (item['more_info'] is Map && item['more_info']['encrypted_media_url'] != null) {
          extras['encrypted_media_url'] = item['more_info']['encrypted_media_url'].toString();
        }

        tracks.add(MusicTrack(
          id: id,
          title: title,
          artist: artist,
          album: album,
          duration: duration,
          artworkUrl: artworkUrl,
          source: 'jiosaavn',
          extras: extras,
        ));
      } catch (e) {
        _log.warning('Failed to parse JioSaavn browse song: $e');
      }
    }
    return tracks;
  }

  Future<List<MusicTrack>> _browseEndpoint(String url, String id) async {
    final baseUrl = await _getEffectiveBaseUrl();
    final isAlbums = url.contains('albums');
    final activeBaseUrl = url.startsWith(baseUrl) ? baseUrl : _baseUrl;
    final endpointPath = isAlbums ? 'api/albums' : 'api/playlists';

    // 1. Try worker endpoint
    try {
      _log.info('Browsing JioSaavn endpoint $url for id: $id');
      final response = await _dio.get<Map<String, dynamic>>(
        '$activeBaseUrl/$endpointPath',
        queryParameters: {'id': id},
      ).timeout(const Duration(seconds: 8));

      final tracks = _parseBrowseResponse(response.data);
      if (tracks.isNotEmpty) return tracks;
    } catch (e) {
      _log.warning('JioSaavn browse endpoint failed: $e');
    }

    // 2. Direct Official JioSaavn content.getAlbumDetails / playlist.getDetails Fallback
    try {
      final callName = isAlbums ? 'content.getAlbumDetails' : 'playlist.getDetails';
      final idParam = isAlbums ? 'albumid' : 'listid';
      _log.info('Falling back to official direct JioSaavn $callName for id: $id');
      final directResponse = await _dio.get<dynamic>(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': callName,
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          idParam: id,
        },
      ).timeout(const Duration(seconds: 6));

      if (directResponse.statusCode == 200 && directResponse.data != null) {
        final directTracks = _parseBrowseResponse(directResponse.data);
        if (directTracks.isNotEmpty) return directTracks;
      }
    } catch (e2) {
      _log.error('Official JioSaavn direct browse fallback failed: $e2');
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    final baseUrl = await _getEffectiveBaseUrl();
    final url = '$baseUrl/api/search/artists';
    try {
      _log.info('Searching JioSaavn artists for: $query');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'query': query},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final body = response.data!;
      final success = body['success'] as bool? ?? false;
      if (!success) return [];

      final dataMap = body['data'] as Map<String, dynamic>?;
      if (dataMap == null) return [];

      final results = dataMap['results'] as List<dynamic>? ?? [];
      return results.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e, s) {
      _log.error('JioSaavn artist search failed: $e', e, s);
      if (baseUrl != _baseUrl) {
        try {
          _log.info('Falling back to default JioSaavn base URL for artist search: $_baseUrl');
          final response = await _dio.get<Map<String, dynamic>>(
            '$_baseUrl/api/search/artists',
            queryParameters: {'query': query},
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 && response.data != null) {
            final body = response.data!;
            final success = body['success'] as bool? ?? false;
            if (success) {
              final dataMap = body['data'] as Map<String, dynamic>?;
              if (dataMap != null) {
                final results = dataMap['results'] as List<dynamic>? ?? [];
                return results.map((r) => Map<String, dynamic>.from(r as Map)).toList();
              }
            }
          }
        } catch (e2) {
          _log.error('JioSaavn artist search fallback failed: $e2');
        }
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    final baseUrl = await _getEffectiveBaseUrl();
    final url = '$baseUrl/api/search/albums';
    try {
      _log.info('Searching JioSaavn albums for: $query');
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'query': query, 'limit': 30},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data!;
        final success = body['success'] as bool? ?? false;
        if (success) {
          final dataMap = body['data'] as Map<String, dynamic>?;
          if (dataMap != null) {
            final results = dataMap['results'] as List<dynamic>? ?? [];
            return results.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          }
        }
      }
    } catch (e) {
      _log.warning('JioSaavn primary album search failed: $e');
    }

    // Direct JioSaavn API fallback for album search
    try {
      _log.info('Falling back to official direct JioSaavn album search for: $query');
      final directResponse = await _dio.get<dynamic>(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getAlbumResults',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'n': 30,
          'p': '1',
          'q': query,
        },
      ).timeout(const Duration(seconds: 6));

      if (directResponse.statusCode == 200 && directResponse.data != null) {
        final data = directResponse.data;
        List<dynamic>? list;
        if (data is Map) {
          if (data['results'] is List) {
            list = data['results'] as List;
          } else if (data['albums'] is Map && data['albums']['data'] is List) {
            list = data['albums']['data'] as List;
          } else if (data['data'] is Map && data['data']['results'] is List) {
            list = data['data']['results'] as List;
          }
        }
        if (list != null && list.isNotEmpty) {
          return list.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        }
      }
    } catch (e2) {
      _log.error('Official JioSaavn album search fallback failed: $e2');
    }

    return [];
  }
}
