import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'music_track.dart';

/// Service for importing and fetching Spotify playlists, albums, and tracks without API keys.
class SpotifyService {
  final Dio _dio;
  final _log = AppLogger('SpotifyService');

  SpotifyService(this._dio);

  /// Extracts the Spotify ID and entity type (playlist, album, track) from any Spotify URL.
  Map<String, String>? parseSpotifyUrl(String url) {
    final cleanUrl = url.trim();
    final regExp = RegExp(r'(?:open\.spotify\.com|spotify:)(?:\/|:)(playlist|album|track)(?:\/|:)([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(cleanUrl);
    if (match != null) {
      return {
        'type': match.group(1)!,
        'id': match.group(2)!,
      };
    }
    // If only an ID was provided (typically 22 chars)
    if (cleanUrl.length == 22 && !cleanUrl.contains(' ')) {
      return {
        'type': 'playlist',
        'id': cleanUrl,
      };
    }
    return null;
  }

  /// Resolves the authentic unique high-res album artwork for any individual Spotify track.
  Future<String> resolveTrackArtwork(String trackId, {String fallback = ''}) async {
    final cleanId = trackId.replaceAll('spotify:track:', '').replaceAll('spotify_', '').trim();
    if (cleanId.length == 22 && !cleanId.contains('_') && !cleanId.contains(' ')) {
      try {
        final res = await _dio.get<dynamic>(
          'https://open.spotify.com/oembed',
          queryParameters: {'url': 'https://open.spotify.com/track/$cleanId'},
        ).timeout(const Duration(seconds: 3));


        if (res.statusCode == 200 && res.data != null) {
          final data = res.data is String ? jsonDecode(res.data as String) : res.data;
          if (data is Map<String, dynamic>) {
            var img = data['thumbnail_url']?.toString() ?? '';
            if (img.isNotEmpty) {
              img = img.replaceAll('ab67616d00001e02', 'ab67616d0000b273');
              return img;
            }
          }
        }
      } catch (_) {}
    }
    return fallback;
  }

  /// Fetches track metadata for a Spotify Playlist using the open embed endpoint.
  Future<Map<String, dynamic>?> fetchPlaylist(String playlistId) async {
    final cleanId = playlistId.contains('/') ? (parseSpotifyUrl(playlistId)?['id'] ?? playlistId) : playlistId;
    final embedUrl = 'https://open.spotify.com/embed/playlist/$cleanId';

    try {
      _log.info('Fetching Spotify playlist via open embed: $cleanId');
      final res = await _dio.get<String>(
        embedUrl,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.data != null) {
        final match = RegExp(r'<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>', dotAll: true).firstMatch(res.data!);
        if (match != null) {
          final jsonData = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final state = jsonData['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;
          if (state != null) {
            final title = state['title']?.toString() ?? (state['name']?.toString() ?? 'Spotify Playlist');
            final artworkUrl = state['visualIdentity']?['image']?[0]?['url']?.toString() ?? 
                               (state['coverArt']?['sources']?[0]?['url']?.toString() ?? '');
            final trackListRaw = (state['trackList'] as List<dynamic>?) ?? [];

            final List<MusicTrack> tracks = [];
            final futures = trackListRaw.take(30).map((t) async {
              if (t is! Map<String, dynamic>) return null;
              final tTitle = t['title']?.toString() ?? 'Unknown';
              final tArtist = t['subtitle']?.toString() ?? 'Spotify Artist';
              final tDurationMs = (t['duration'] as num?)?.toInt() ?? 180000;
              final rawUri = t['uri']?.toString() ?? '';
              final tId = rawUri.replaceAll('spotify:track:', '').trim();

              String trackImg = artworkUrl;
              if (tId.isNotEmpty && tId.length == 22) {
                final resolved = await resolveTrackArtwork(tId, fallback: artworkUrl);
                if (resolved.isNotEmpty) {
                  trackImg = resolved;
                }
              }

              return MusicTrack(
                id: 'spotify_${tId.isNotEmpty ? tId : '${tTitle}_$tArtist'}',
                title: tTitle,
                artist: tArtist,
                album: title,
                duration: Duration(milliseconds: tDurationMs),
                artworkUrl: trackImg,
                source: 'Spotify',
              );
            }).toList();

            final resolvedTracks = await Future.wait(futures);
            for (final r in resolvedTracks) {
              if (r != null) tracks.add(r);
            }

            _log.info('Successfully parsed Spotify playlist "$title" with ${tracks.length} tracks');
            return {
              'id': cleanId,
              'title': title,
              'artworkUrl': artworkUrl,
              'tracks': tracks,
            };
          }
        }
      }
    } catch (e, s) {
      _log.error('Failed to fetch Spotify playlist ($cleanId): $e', e, s);
    }
    return null;
  }

  /// Fetches track metadata for a Spotify Album using the open embed endpoint.
  Future<Map<String, dynamic>?> fetchAlbum(String albumId) async {
    final cleanId = albumId.contains('/') ? (parseSpotifyUrl(albumId)?['id'] ?? albumId) : albumId;
    final embedUrl = 'https://open.spotify.com/embed/album/$cleanId';

    try {
      _log.info('Fetching Spotify album via open embed: $cleanId');
      final res = await _dio.get<String>(
        embedUrl,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.data != null) {
        final match = RegExp(r'<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>', dotAll: true).firstMatch(res.data!);
        if (match != null) {
          final jsonData = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final state = jsonData['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;
          if (state != null) {
            final title = state['title']?.toString() ?? (state['name']?.toString() ?? 'Spotify Album');
            final artist = state['subtitle']?.toString() ?? 'Spotify Artist';
            final artworkUrl = state['visualIdentity']?['image']?[0]?['url']?.toString() ?? 
                               (state['coverArt']?['sources']?[0]?['url']?.toString() ?? '');
            final trackListRaw = (state['trackList'] as List<dynamic>?) ?? [];

            final List<MusicTrack> tracks = [];
            for (final t in trackListRaw) {
              if (t is! Map<String, dynamic>) continue;
              final tTitle = t['title']?.toString() ?? 'Unknown';
              final tArtist = t['subtitle']?.toString() ?? artist;
              final tDurationMs = (t['duration'] as num?)?.toInt() ?? 180000;
              final tId = t['uri']?.toString().replaceAll('spotify:track:', '') ?? '${tTitle}_$tArtist';

              tracks.add(MusicTrack(
                id: 'spotify_$tId',
                title: tTitle,
                artist: tArtist,
                album: title,
                duration: Duration(milliseconds: tDurationMs),
                artworkUrl: artworkUrl,
                source: 'Spotify',
              ));
            }

            return {
              'id': cleanId,
              'title': title,
              'artist': artist,
              'artworkUrl': artworkUrl,
              'tracks': tracks,
            };
          }
        }
      }
    } catch (e, s) {
      _log.error('Failed to fetch Spotify album ($cleanId): $e', e, s);
    }
    return null;
  }

  static const Map<String, String> _kKnownSpotifyArtistIds = {
    'taylor swift': '06HL4z0CvFAxyc27GXpf02',
    'the weeknd': '1Xyo4u8uXC1ZmMpatF05PJ',
    'arijit singh': '4YRxDV8wJFPHPTeXepOstw',
    'billie eilish': '6qqNVTkY8uBg9cP3Jd7DAH',
    'dua lipa': '6M2wZ9GZgrQXHCFfjv46we',
    'ed sheeran': '6eUKZXaKkcviH0Ku9w2n3V',
    'justin bieber': '1uNFoZAHBGtllmzznpCI3s',
    'ariana grande': '66CXWjxzNUsdJxJ2JdwvnR',
    'bruno mars': '0du5cEVh5yTK9QJze8zA0C',
    'bad bunny': '4q3ewBCX7sLwd24euuV69X',
    'drake': '3TVXtAsR1Inumwj472S9r4',
    'post malone': '246dkjvS1zLTti9anFvr8A',
    'olivia rodrigo': '1McMsnEElThX1knmY4oliG',
    'coldplay': '4gzpq5YvW9XsxdJQX74Z3Y',
    'eminem': '7dGJo4pcD2V6ioO0SIMEdZ',
    'kendrick lamar': '2YZyLoL8N0Wb9xBt1NhZWg',
    'sabrina carpenter': '74KM79TiuVKeVCqs8QtB0B',
    'tate mcrae': '45dkTj5mMRSjrmvg6eoWs5',
    'chappell roan': '7GlBOeep6PqTfFi59PTJUt',
  };

  /// Fetches top tracks for a Spotify Artist using the open embed endpoint.
  Future<List<MusicTrack>> fetchArtist(String artistId) async {
    final cleanId = artistId.contains('/') ? (parseSpotifyUrl(artistId)?['id'] ?? artistId) : artistId;
    final embedUrl = 'https://open.spotify.com/embed/artist/$cleanId';

    try {
      _log.info('Fetching Spotify artist via open embed: $cleanId');
      final res = await _dio.get<String>(
        embedUrl,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.data != null) {
        final match = RegExp(r'<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>', dotAll: true).firstMatch(res.data!);
        if (match != null) {
          final jsonData = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final state = jsonData['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;
          if (state != null) {
            final artistName = state['title']?.toString() ?? (state['name']?.toString() ?? 'Spotify Artist');
            final artworkUrl = state['visualIdentity']?['image']?[0]?['url']?.toString() ?? 
                               (state['coverArt']?['sources']?[0]?['url']?.toString() ?? '');
            final trackListRaw = (state['trackList'] as List<dynamic>?) ?? [];

            final List<MusicTrack> tracks = [];
            final futures = trackListRaw.take(25).map((t) async {
              if (t is! Map<String, dynamic>) return null;
              final tTitle = t['title']?.toString() ?? 'Unknown';
              final tArtist = t['subtitle']?.toString() ?? artistName;
              final tDurationMs = (t['duration'] as num?)?.toInt() ?? 180000;
              final rawUri = t['uri']?.toString() ?? '';
              final tId = rawUri.replaceAll('spotify:track:', '').trim();

              String trackImg = artworkUrl;
              if (tId.isNotEmpty && tId.length == 22) {
                final resolved = await resolveTrackArtwork(tId, fallback: artworkUrl);
                if (resolved.isNotEmpty) {
                  trackImg = resolved;
                }
              }

              return MusicTrack(
                id: 'spotify_${tId.isNotEmpty ? tId : '${tTitle}_$tArtist'}',
                title: tTitle,
                artist: tArtist,
                album: artistName,
                duration: Duration(milliseconds: tDurationMs),
                artworkUrl: trackImg,
                source: 'Spotify',
              );
            }).toList();

            final resolvedTracks = await Future.wait(futures);
            for (final r in resolvedTracks) {
              if (r != null) tracks.add(r);
            }

            return tracks;
          }
        }
      }
    } catch (e, s) {
      _log.error('Failed to fetch Spotify artist ($cleanId): $e', e, s);
    }
    return [];
  }


  /// Searches Spotify tracks across top charts and artist collections.
  Future<List<MusicTrack>> search(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final List<MusicTrack> results = [];
    final Set<String> seenIds = {};

    // 1. Check if query matches a known Spotify artist
    for (final entry in _kKnownSpotifyArtistIds.entries) {
      if (cleanQuery.contains(entry.key) || entry.key.contains(cleanQuery)) {
        final artistTracks = await fetchArtist(entry.value);
        for (final t in artistTracks) {
          if (!seenIds.contains(t.id)) {
            seenIds.add(t.id);
            results.add(t);
          }
        }
        if (results.length >= limit) return results.take(limit).toList();
      }
    }

    // 2. Search Spotify top chart playlists
    final playlistsToSearch = ['37i9dQZF1DXcBWIGoYBM5M', '37i9dQZEVXbMDoHDwVN2tF', '37i9dQZF1DX0XUsuxWHRQd'];
    for (final pid in playlistsToSearch) {
      final p = await fetchPlaylist(pid);
      if (p != null && p['tracks'] is List<MusicTrack>) {
        final tracks = p['tracks'] as List<MusicTrack>;
        for (final t in tracks) {
          final matches = t.title.toLowerCase().contains(cleanQuery) || t.artist.toLowerCase().contains(cleanQuery);
          if (matches && !seenIds.contains(t.id)) {
            seenIds.add(t.id);
            results.add(t);
          }
        }
      }
      if (results.length >= limit) return results.take(limit).toList();
    }

    return results.take(limit).toList();
  }
}

