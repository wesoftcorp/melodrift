import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'music_provider.dart';
import 'music_track.dart';

class InnerTubeService implements MusicProvider {
  final Dio _dio;
  final _log = AppLogger('InnerTubeService');
  static const _baseUrl = 'https://www.youtube.com';

  InnerTubeService(this._dio);

  @override
  String get name => 'youtube';

  @override
  Future<List<MusicTrack>> search(String query) async {
    const url = '$_baseUrl/youtubei/v1/search?key=AIzaSyAo1OJ2Cr2anq0m-2Qu1s1n-2H3sD4a5a6';
    
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'X-Goog-Api-Format-Version': '2',
      'X-YouTube-Client-Name': '26',
      'X-YouTube-Client-Version': '1.20240101.00.00',
      'Content-Type': 'application/json',
      'Referer': 'https://music.youtube.com/',
      'Origin': 'https://music.youtube.com',
    };

    final payload = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.00.00',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 330,
        }
      },
      'query': query,
      'params': 'EgWKAQIIAWoKEA4QChADEAQQCg==', // Songs filter
    };

    try {
      _log.info('Performing InnerTube search for: $query');
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 || response.data == null) {
        _log.error('InnerTube search returned status code: ${response.statusCode}');
        return [];
      }

      final Map<String, dynamic> data = response.data!;
      final contents = data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (contents == null) {
        _log.warning('No contents found in InnerTube response');
        return [];
      }

      Map<String, dynamic>? musicShelf;
      for (final section in contents) {
        final sectionMap = section as Map<String, dynamic>?;
        if (sectionMap != null && sectionMap['musicShelfRenderer'] != null) {
          musicShelf = sectionMap['musicShelfRenderer'] as Map<String, dynamic>?;
          break;
        }
      }

      if (musicShelf == null) {
        _log.warning('No musicShelfRenderer found in search response');
        return [];
      }

      final items = musicShelf['contents'] as List<dynamic>? ?? [];
      final List<MusicTrack> tracks = [];

      for (final item in items) {
        final itemMap = item as Map<String, dynamic>?;
        if (itemMap == null) continue;
        final renderer = itemMap['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
        if (renderer == null) continue;

        final track = _parseTrackRenderer(renderer);
        if (track != null) {
          tracks.add(track);
        }
      }

      return tracks;
    } catch (e, s) {
      _log.error('InnerTube search failed: $e', e, s);
      return [];
    }
  }

  @override
  Future<List<MusicTrack>> browse(String browseId) async {
    const url = '$_baseUrl/youtubei/v1/browse?key=AIzaSyAo1OJ2Cr2anq0m-2Qu1s1n-2H3sD4a5a6';
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'X-Goog-Api-Format-Version': '2',
      'X-YouTube-Client-Name': '26',
      'X-YouTube-Client-Version': '1.20240101.00.00',
      'Content-Type': 'application/json',
      'Referer': 'https://music.youtube.com/',
      'Origin': 'https://music.youtube.com',
    };

    final payload = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.00.00',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 330,
        },
      },
      'browseId': browseId,
    };

    try {
      _log.info('Performing InnerTube browse for: $browseId');
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 || response.data == null) {
        _log.error('InnerTube browse returned status code: ${response.statusCode}');
        return [];
      }

      final data = response.data!;
      final List<Map<String, dynamic>> renderers = [];
      _findListItemRenderers(data, renderers);

      final List<MusicTrack> tracks = [];
      for (final renderer in renderers) {
        final track = _parseTrackRenderer(renderer);
        if (track != null) {
          tracks.add(track);
        }
      }

      return tracks;
    } catch (e, s) {
      _log.error('InnerTube browse failed for $browseId: $e', e, s);
      return [];
    }
  }

  void _findListItemRenderers(dynamic node, List<Map<String, dynamic>> results) {
    if (node is Map) {
      if (node.containsKey('musicResponsiveListItemRenderer')) {
        final rendererMap = node['musicResponsiveListItemRenderer'] as Map<dynamic, dynamic>?;
        if (rendererMap != null) {
          results.add(Map<String, dynamic>.from(rendererMap));
        }
      }
      for (final value in node.values) {
        _findListItemRenderers(value, results);
      }
    } else if (node is List) {
      for (final element in node) {
        _findListItemRenderers(element, results);
      }
    }
  }

  MusicTrack? _parseTrackRenderer(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List<dynamic>? ?? [];
      if (flexColumns.isEmpty) return null;

      // Extract Title from first flex column
      final firstCol = flexColumns[0] as Map<String, dynamic>?;
      final firstColRenderer = firstCol?['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?;
      final titleText = firstColRenderer?['text']?['runs']?[0]?['text'] as String?;
      final title = titleText ?? 'Unknown';

      // Extract Metadata (Artist, Album, Duration) from second flex column
      final secondCol = flexColumns[1] as Map<String, dynamic>?;
      final secondColRenderer = secondCol?['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?;
      final runs = secondColRenderer?['text']?['runs'] as List<dynamic>? ?? [];

      // Group runs by bullet separator " • "
      final List<List<String>> groups = [[]];
      for (final run in runs) {
        final runMap = run as Map<String, dynamic>?;
        if (runMap == null) continue;
        final text = runMap['text'] as String?;
        if (text == null) continue;
        if (text.trim() == '•') {
          groups.add([]);
        } else {
          groups.last.add(text);
        }
      }

      String joinGroup(List<String> group) => group.join('').trim();

      String parsedArtists = 'Unknown';
      String parsedAlbum = 'Unknown';
      Duration parsedDuration = Duration.zero;

      // Find duration group (usually the last group matching a colon pattern)
      int durationIndex = -1;
      final durationRegex = RegExp(r'^\d+:\d+(:\d+)?$');
      
      if (groups.isNotEmpty) {
        final lastText = joinGroup(groups.last);
        if (durationRegex.hasMatch(lastText)) {
          durationIndex = groups.length - 1;
          final parts = lastText.split(':').map(int.parse).toList();
          if (parts.length == 2) {
            parsedDuration = Duration(minutes: parts[0], seconds: parts[1]);
          } else if (parts.length == 3) {
            parsedDuration = Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
          }
        }
      }

      // Filter out the duration group to extract artists and album
      final List<List<String>> metaGroups = [];
      for (int j = 0; j < groups.length; j++) {
        if (j != durationIndex && joinGroup(groups[j]).isNotEmpty) {
          metaGroups.add(groups[j]);
        }
      }

      if (metaGroups.isNotEmpty) {
        parsedArtists = joinGroup(metaGroups[0]);
      }
      if (metaGroups.length > 1) {
        parsedAlbum = joinGroup(metaGroups[1]);
      }

      // Extract Video ID
      final videoId = (renderer['playlistItemData']?['videoId'] ?? 
                       renderer['navigationEndpoint']?['watchEndpoint']?['videoId']) as String?;
      if (videoId == null) return null;

      // Extract Artwork URL
      final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>? ?? [];
      final artworkUrl = thumbnails.isNotEmpty ? (thumbnails.last as Map<String, dynamic>)['url'] as String? ?? '' : '';

      return MusicTrack(
        id: videoId,
        title: title,
        artist: parsedArtists,
        album: parsedAlbum,
        duration: parsedDuration,
        artworkUrl: artworkUrl,
        source: 'youtube',
        extras: {
          'videoId': videoId,
        },
      );
    } catch (e) {
      _log.warning('Failed to parse track: $e');
      return null;
    }
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    // Playback and streaming endpoint resolution is handled by JioSaavnBridge (or YouTube resolution in later steps)
    return null;
  }
}
