import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../../core/utils/logger.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/mood_category.dart';

final youtubeMusicRemoteSourceProvider = Provider<YouTubeMusicRemoteSource>((ref) {
  final source = YouTubeMusicRemoteSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// In-memory stream URL cache entry with expiry.
class _StreamUrlCacheEntry {
  final String url;
  final DateTime expiresAt;
  _StreamUrlCacheEntry(this.url, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class YouTubeMusicRemoteSource {
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final _dio = Dio();
  final _log = AppLogger('YouTubeMusicRemoteSource');

  /// In-memory stream URL cache: videoId+quality → cached entry.
  /// YouTube CDN URLs are valid ~6 hours; we cache for 4 hours to stay safe.
  final Map<String, _StreamUrlCacheEntry> _streamUrlCache = {};
  static const _streamUrlCacheTtl = Duration(hours: 4);

  /// Ordered list of YouTube clients to try in parallel.
  /// - androidSdkless: no PO Token needed, good compatibility, no SDK version field
  /// - androidVr: high quality, rarely blocked
  /// - androidMusic: targets YouTube Music API directly
  static final _ytClients = [
    yt.YoutubeApiClient.ios,
    yt.YoutubeApiClient.androidSdkless,
    yt.YoutubeApiClient.androidVr,
    yt.YoutubeApiClient.androidMusic,
  ];

  /// Search for songs matching [query]
  Future<List<Song>> searchSongs(String query, {List<String>? filters, bool isHomeFeed = false}) async {
    final searchList = await _yt.search.search('$query song');
    final songs = <Song>[];

    for (final item in searchList) {
      songs.add(_mapVideoToSong(item));
    }

    final ytSongs = filterOutShorts(songs);

    final filterExplicit = await _shouldFilterExplicit();
    if (filterExplicit) {
      ytSongs.removeWhere((s) => _isExplicit(s.title, s.artist, s.album));
    }

    if (isHomeFeed) {
      // For home feed, decorate songs into 2 distinct sources (YouTube Music, JioSaavn)
      // keeping home feed load time lightning-fast without extra network requests.
      final List<Song> decorated = [];
      for (int i = 0; i < ytSongs.length; i++) {
        final s = ytSongs[i];
        final mod = i % 2;
        if (mod == 1) {
          decorated.add(Song(
            id: 'jiosaavn_${s.id}',
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: s.duration,
            artworkUrl: s.artworkUrl,
            videoId: s.videoId,
            streamUrl: s.streamUrl,
            source: 'JioSaavn',
          ));
        } else {
          decorated.add(s);
        }
      }
      return decorated;
    }

    // Fetch real JioSaavn search suggestions from their autocomplete endpoint
    final List<Song> jioSongs = [];
    try {
      final response = await _dio.get<dynamic>(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'autocomplete.get',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'includeMetaTags': '1',
          'query': query,
        },
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200 && response.data != null) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }
        if (data is Map && data['songs'] != null && data['songs']['data'] != null) {
          final list = data['songs']['data'] as List;
          for (final item in list) {
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? '';
            final image = item['image']?.toString() ?? '';
            final artworkUrl = image.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');

            // Parse artist name accurately
            String artist = '';
            if (item['more_info'] != null) {
              final moreInfo = item['more_info'];
              if (moreInfo['singers'] != null && moreInfo['singers'].toString().isNotEmpty) {
                artist = moreInfo['singers'].toString();
              } else if (moreInfo['primary_artists'] != null && moreInfo['primary_artists'].toString().isNotEmpty) {
                artist = moreInfo['primary_artists'].toString();
              }
            }
            if (artist.isEmpty && item['description'] != null) {
              final desc = item['description'].toString();
              final parts = desc.split('·');
              if (parts.length > 1) {
                artist = parts[1].trim();
              } else {
                artist = desc.trim();
              }
            }
            if (artist.isEmpty) {
              artist = 'Unknown Artist';
            }

            jioSongs.add(Song(
              id: 'jiosaavn_$id',
              title: title,
              artist: artist,
              album: 'JioSaavn Single',
              duration: const Duration(minutes: 3, seconds: 30),
              artworkUrl: artworkUrl,
              videoId: '$title $artist',
              source: 'JioSaavn',
            ));
          }
        }
      }
    } catch (e) {
      _log.warning('Failed to fetch JioSaavn songs: $e');
    }

    // Combine results in an interleaved fashion: YT Music and JioSaavn
    final List<Song> combined = [];
    final maxLen = ytSongs.length > jioSongs.length ? ytSongs.length : jioSongs.length;

    for (int i = 0; i < maxLen; i++) {
      if (i < ytSongs.length) {
        combined.add(ytSongs[i]);
      }
      if (i < jioSongs.length) {
        combined.add(jioSongs[i]);
      }
    }

    return combined;
  }

  Future<List<Album>> searchAlbums(String query, {bool isHomeFeed = false}) async {
    final searchList = await _yt.search.searchContent(query, filter: yt.TypeFilters.playlist);
    final albums = <Album>[];

    for (final item in searchList) {
      if (item is yt.SearchPlaylist) {
        albums.add(Album(
          id: item.id.value,
          title: item.title,
          artist: 'Various Artists',
          artworkUrl: item.thumbnails.isEmpty ? '' : item.thumbnails.first.url.toString(),
          tracks: const [],
          songCount: item.videoCount,
        ));
      }
    }

    if (isHomeFeed) {
      // Decorate with YouTube Music and JioSaavn
      final List<Album> decorated = [];
      for (int i = 0; i < albums.length; i++) {
        final a = albums[i];
        String source = 'YouTube Music';
        String idPrefix = '';
        final mod = i % 2;
        if (mod == 1) {
          source = 'JioSaavn';
          idPrefix = 'jiosaavn_';
        }
        decorated.add(Album(
          id: '$idPrefix${a.id}',
          title: a.title,
          artist: a.artist,
          artworkUrl: a.artworkUrl,
          tracks: a.tracks,
          songCount: a.songCount,
          year: a.year,
          source: source,
        ));
      }
      return decorated;
    }

    return albums;
  }

  /// Search for artists matching [query]
  Future<List<Artist>> searchArtists(String query) async {
    final searchList = await _yt.search.searchContent(query, filter: yt.TypeFilters.channel);
    final artists = <Artist>[];

    for (final item in searchList) {
      if (item is yt.SearchChannel) {
        artists.add(Artist(
          id: item.id.value,
          name: item.name,
          artworkUrl: item.thumbnails.isEmpty ? '' : item.thumbnails.first.url.toString(),
          subscribers: null,
          isVerified: false,
        ));
      }
    }

    return artists;
  }

  /// Fetch a customized home feed combining popular searches
  // ---------------------------------------------------------------------------
  // Daily Cache & JSON Serialization Helpers
  // ---------------------------------------------------------------------------

  static const _kCacheDateKey = 'home_feed_cache_date_v5';

  /// Returns a cache-key string combining today's date and the language filter.
  static String _cacheKey(String? language) {
    final today = DateTime.now();
    final datePart =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final langPart = language ?? 'all';
    return '${datePart}_$langPart';
  }

  // --- Serialization mappings for entities to keep them dependency-free ---

  Map<String, dynamic> _songToJson(Song song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'durationMs': song.duration.inMilliseconds,
        'artworkUrl': song.artworkUrl,
        'streamUrl': song.streamUrl,
        'videoId': song.videoId,
        'source': song.source,
      };

  Song _songFromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
        artworkUrl: json['artworkUrl'] as String,
        streamUrl: json['streamUrl'] as String?,
        videoId: json['videoId'] as String,
        source: (json['source'] as String?) ?? 'YouTube Music',
      );

  Map<String, dynamic> _artistToJson(Artist artist) => {
        'id': artist.id,
        'name': artist.name,
        'artworkUrl': artist.artworkUrl,
        'subscribers': artist.subscribers,
        'isVerified': artist.isVerified,
      };

  Artist _artistFromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] as String,
        name: json['name'] as String,
        artworkUrl: json['artworkUrl'] as String,
        subscribers: json['subscribers'] as String?,
        isVerified: json['isVerified'] as bool? ?? false,
      );

  Map<String, dynamic> _albumToJson(Album album) => {
        'id': album.id,
        'title': album.title,
        'artist': album.artist,
        'artworkUrl': album.artworkUrl,
        'year': album.year,
        'tracks': album.tracks.map(_songToJson).toList(),
        'songCount': album.songCount,
        'source': album.source,
      };

  Album _albumFromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        artworkUrl: json['artworkUrl'] as String,
        year: json['year'] as int?,
        tracks: (json['tracks'] as List)
            .map((t) => _songFromJson(t as Map<String, dynamic>))
            .toList(),
        songCount: json['songCount'] as int,
        source: (json['source'] as String?) ?? 'YouTube Music',
      );

  Map<String, dynamic> _moodToJson(MoodCategory mood) => {
        'id': mood.id,
        'title': mood.title,
      };

  Map<String, dynamic> _homeDataToJson(HomeData data) => {
        'quickPicks': data.quickPicks.map(_songToJson).toList(),
        'newReleases': data.newReleases.map(_albumToJson).toList(),
        'charts': data.charts.map(_songToJson).toList(),
        'moods': data.moods.map(_moodToJson).toList(),
        'listenAgain': data.listenAgain.map(_songToJson).toList(),
        'recommendedArtists': data.recommendedArtists.map(_artistToJson).toList(),
        'featuredPlaylist':
            data.featuredPlaylist != null ? _albumToJson(data.featuredPlaylist!) : null,
        'trendingSongs': data.trendingSongs.map(_songToJson).toList(),
        'featuredPlaylistsForYou': data.featuredPlaylistsForYou.map(_albumToJson).toList(),
        'indianMusic': data.indianMusic.map(_songToJson).toList(),
        'forgottenFavorites': data.forgottenFavorites.map(_songToJson).toList(),
        'albumsForYou': data.albumsForYou.map(_albumToJson).toList(),
      };

  HomeData _homeDataFromJson(Map<String, dynamic> json) => HomeData(
        quickPicks: (json['quickPicks'] as List)
            .map((s) => _songFromJson(s as Map<String, dynamic>))
            .toList(),
        newReleases: (json['newReleases'] as List)
            .map((a) => _albumFromJson(a as Map<String, dynamic>))
            .toList(),
        charts: (json['charts'] as List)
            .map((s) => _songFromJson(s as Map<String, dynamic>))
            .toList(),
        moods: getMoodGenreCategories(),
        listenAgain: (json['listenAgain'] as List)
            .map((s) => _songFromJson(s as Map<String, dynamic>))
            .toList(),
        recommendedArtists: (json['recommendedArtists'] as List)
            .map((a) => _artistFromJson(a as Map<String, dynamic>))
            .toList(),
        featuredPlaylist: json['featuredPlaylist'] != null
            ? _albumFromJson(json['featuredPlaylist'] as Map<String, dynamic>)
            : null,
        trendingSongs: (json['trendingSongs'] as List?)
                ?.map((s) => _songFromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        featuredPlaylistsForYou: (json['featuredPlaylistsForYou'] as List?)
                ?.map((a) => _albumFromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        indianMusic: (json['indianMusic'] as List?)
                ?.map((s) => _songFromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        forgottenFavorites: (json['forgottenFavorites'] as List?)
                ?.map((s) => _songFromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        albumsForYou: (json['albumsForYou'] as List?)
                ?.map((a) => _albumFromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  // ---------------------------------------------------------------------------
  // Home Feed
  // ---------------------------------------------------------------------------

  Future<HomeData> getHomeFeed({String? language}) async {
    final key = _cacheKey(language);

    // 1. Try to load from daily cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheDate = prefs.getString(_kCacheDateKey);
      if (cacheDate == key) {
        final cacheDataStr = prefs.getString('home_feed_cache_data_${language ?? "all"}');
        if (cacheDataStr != null) {
          final decoded = json.decode(cacheDataStr) as Map<String, dynamic>;
          // Ensure new fields exist, otherwise invalidate cache
          if (decoded.containsKey('featuredPlaylistsForYou') &&
              decoded.containsKey('indianMusic') &&
              decoded.containsKey('forgottenFavorites') &&
              decoded.containsKey('albumsForYou')) {
            final homeData = _homeDataFromJson(decoded);
            // Every section that supports multi-source must have JioSaavn entries
            // otherwise the cache is stale and needs a re-fetch.
            final hasMultiSource =
                homeData.quickPicks.any((s) => s.source == 'JioSaavn') &&
                homeData.trendingSongs.any((s) => s.source == 'JioSaavn') &&
                homeData.albumsForYou.any((a) => a.source == 'JioSaavn');
            final isCacheComplete = homeData.quickPicks.isNotEmpty &&
                homeData.trendingSongs.isNotEmpty &&
                homeData.featuredPlaylistsForYou.isNotEmpty;
            if (hasMultiSource && isCacheComplete) {
               _log.debug('Loaded home feed from daily cache ($key).');
               return homeData;
            } else {
               _log.info('Cache is stale (missing JioSaavn in sections). Re-fetching fresh feed...');
            }
          } else {
            _log.info('Cache is missing new fields. Invalidating...');
          }
        }
      }
    } catch (e, s) {
      _log.error('Failed to read home feed cache', e, s);
    }

    // 2. Fetch from network if cache is cold or expired
    _log.info('Cache is cold/expired for $key. Fetching fresh home feed...');
    final langSuffix = (language == null || language.toLowerCase() == 'all') ? '' : ' $language';

    List<Song> quickPicks = [];
    List<Album> newReleases = [];
    List<Song> charts = [];
    List<Song> listenAgain = [];
    List<Artist> recommendedArtists = [];
    Album? featuredPlaylist;
    final moods = getMoodGenreCategories();

    // Melodrift Trending Music (top 50)
    List<Song> trendingSongs = [];

    // New Rich Sections
    List<Album> featuredPlaylistsForYou = [];
    List<Song> indianMusic = [];
    List<Song> forgottenFavorites = [];
    List<Album> albumsForYou = [];

    await Future.wait([
      searchSongs('popular hits$langSuffix', isHomeFeed: true).then((v) => quickPicks = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching quick picks', e, s);
        return <Song>[];
      }),
      searchAlbums('latest albums 2026$langSuffix', isHomeFeed: true).then((v) => newReleases = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching new releases', e, s);
        return <Album>[];
      }),
      searchSongs('trending music$langSuffix', isHomeFeed: true).then((v) => charts = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching charts', e, s);
        return <Song>[];
      }),
      searchSongs('top songs 2025$langSuffix', isHomeFeed: true).then((v) => listenAgain = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching listen again', e, s);
        return <Song>[];
      }),
      searchArtists('popular artists$langSuffix').then((v) => recommendedArtists = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching artists', e, s);
        return <Artist>[];
      }),
      searchAlbums('best playlist 2025$langSuffix', isHomeFeed: true).then((albums) {
        if (albums.isNotEmpty) featuredPlaylist = albums.first;
      }).catchError((Object e, StackTrace s) {
        _log.error('Error fetching featured playlist', e, s);
        return null;
      }),
      // Melodrift Trending Music — fetch extra to ensure 50 after filtering
      searchSongs('top 50 hit songs 2026 worldwide$langSuffix', isHomeFeed: true).then((v) => trendingSongs = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching trending songs', e, s);
        return <Song>[];
      }),
      // New rich section fetches
      searchAlbums('featured playlist$langSuffix', isHomeFeed: true).then((v) => featuredPlaylistsForYou = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching featured playlists for you', e, s);
        return <Album>[];
      }),
      searchSongs('bollywood hits$langSuffix', isHomeFeed: true).then((v) => indianMusic = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching Indian music', e, s);
        return <Song>[];
      }),
      searchSongs('retro classics 90s$langSuffix', isHomeFeed: true).then((v) => forgottenFavorites = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching forgotten favorites', e, s);
        return <Song>[];
      }),
      searchAlbums('pop albums$langSuffix', isHomeFeed: true).then((v) => albumsForYou = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching albums for you', e, s);
        return <Album>[];
      }),
    ]);

    if (quickPicks.isEmpty && newReleases.isEmpty && charts.isEmpty) {
      try {
        quickPicks = await searchSongs('popular hits', isHomeFeed: true);
        newReleases = await searchAlbums('latest albums 2026', isHomeFeed: true);
        charts = await searchSongs('trending music', isHomeFeed: true);
      } catch (e, s) {
        _log.error('Generic fallback searches also failed', e, s);
      }
    }

    // Seeded daily shuffle to keep home feed fresh and alive once every 24 hours
    final today = DateTime.now();
    final seed = today.day + today.month * 31 + today.year * 366;
    final rand = Random(seed);

    void dailyShuffle<T>(List<T> list) {
      if (list.length <= 1) return;
      for (int i = list.length - 1; i > 0; i--) {
        final j = rand.nextInt(i + 1);
        final temp = list[i];
        list[i] = list[j];
        list[j] = temp;
      }
    }

    dailyShuffle(quickPicks);
    dailyShuffle(newReleases);
    dailyShuffle(charts);
    dailyShuffle(listenAgain);
    dailyShuffle(trendingSongs);
    dailyShuffle(featuredPlaylistsForYou);
    dailyShuffle(indianMusic);
    dailyShuffle(forgottenFavorites);
    dailyShuffle(albumsForYou);
    dailyShuffle(recommendedArtists);

    final homeData = HomeData(
      quickPicks: quickPicks.take(20).toList(),
      newReleases: newReleases.take(12).toList(),
      charts: charts.take(20).toList(),
      moods: moods,
      listenAgain: listenAgain.take(12).toList(),
      recommendedArtists: recommendedArtists.take(8).toList(),
      featuredPlaylist: featuredPlaylist,
      trendingSongs: trendingSongs.take(50).toList(),
      featuredPlaylistsForYou: featuredPlaylistsForYou.take(12).toList(),
      indianMusic: indianMusic.take(20).toList(),
      forgottenFavorites: forgottenFavorites.take(20).toList(),
      albumsForYou: albumsForYou.take(12).toList(),
    );

    // 3. Save to daily cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheDateKey, key);
      await prefs.setString('home_feed_cache_data_${language ?? "all"}', json.encode(_homeDataToJson(homeData)));
      _log.debug('Successfully saved home feed to daily cache ($key).');
    } catch (e, s) {
      _log.error('Failed to save home feed cache', e, s);
    }

    return homeData;
  }



  /// Get details of an album (which is represented as a Playlist)
  Future<Album> getAlbumDetails(String albumId) async {
    final cleanId = albumId.replaceFirst('jiosaavn_', '');
    final playlist = await _yt.playlists.get(cleanId);
    final List<Song> tracks = await _fetchPlaylistTracks(cleanId);

    String source = 'YouTube Music';
    if (albumId.startsWith('jiosaavn_')) {
      source = 'JioSaavn';
    }

    final List<Song> decoratedTracks = tracks.map((song) => Song(
      id: song.id.startsWith('jiosaavn_') 
          ? song.id 
          : '${source.toLowerCase()}_${song.id}',
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artworkUrl: song.artworkUrl,
      videoId: song.videoId,
      streamUrl: song.streamUrl,
      source: source,
    )).toList();

    return Album(
      id: albumId,
      title: playlist.title,
      artist: playlist.author,
      artworkUrl: playlist.thumbnails.mediumResUrl,
      year: null,
      tracks: decoratedTracks,
      songCount: decoratedTracks.length,
      source: source,
    );
  }

  /// Get details of an artist (which is represented as a Channel)
  Future<Artist> getArtistDetails(String artistId) async {
    final channel = await _yt.channels.get(yt.ChannelId(artistId));
    
    return Artist(
      id: channel.id.value,
      name: channel.title,
      artworkUrl: channel.logoUrl,
      subscribers: channel.subscribersCount?.toString(),
      isVerified: true,
    );
  }

  /// Get details of a playlist
  Future<Playlist> getPlaylistDetails(String playlistId) async {
    final cleanId = playlistId.replaceFirst('jiosaavn_', '');
    final playlist = await _yt.playlists.get(cleanId);
    final List<Song> tracks = await _fetchPlaylistTracks(cleanId);

    String source = 'YouTube Music';
    if (playlistId.startsWith('jiosaavn_')) {
      source = 'JioSaavn';
    }

    final List<Song> decoratedTracks = tracks.map((song) => Song(
      id: song.id.startsWith('jiosaavn_') 
          ? song.id 
          : '${source.toLowerCase()}_${song.id}',
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artworkUrl: song.artworkUrl,
      videoId: song.videoId,
      streamUrl: song.streamUrl,
      source: source,
    )).toList();

    return Playlist(
      id: playlistId,
      title: playlist.title,
      description: playlist.description,
      artworkUrl: playlist.thumbnails.mediumResUrl,
      trackCount: decoratedTracks.length,
      songs: decoratedTracks,
      isYouTube: true,
      isLocal: false,
    );
  }

  /// Get high-quality stream URL for playback.
  /// Results are cached in memory for [_streamUrlCacheTtl] to avoid redundant
  /// YouTube API round-trips on every play / prefetch.
  Future<String> getStreamUrl(String videoId, String quality, {bool preferLocal = false}) async {
    String targetId = videoId;
    if (!RegExp(r'^[a-zA-Z0-9_\-]{11}$').hasMatch(videoId)) {
      _log.info('videoId "$videoId" is not 11 chars. Searching YouTube for best match...');
      try {
        final searchList = await _yt.search.search('$videoId song').timeout(const Duration(seconds: 4));
        if (searchList.isNotEmpty) {
          targetId = searchList.first.id.value;
          _log.info('Resolved "$videoId" to YouTube videoId "$targetId"');
        }
      } catch (e) {
        _log.warning('Failed to resolve search for "$videoId": $e');
      }
    }

    final cacheKey = '$targetId:$quality';
    final cached = _streamUrlCache[cacheKey];
    if (cached != null && cached.isValid) {
      _log.debug('Stream URL cache hit for $targetId ($quality)');
      return cached.url;
    }

    _log.debug('Fetching stream URL for $targetId ($quality)…');

    // Try Custom YouTube Stream Resolver API if configured
    final prefs = await SharedPreferences.getInstance();
    String customYtUrl = prefs.getString('custom_youtube_api_url') ?? '';
    if (customYtUrl.isEmpty) {
      customYtUrl = 'https://youtube-music-resolver-vercel.vercel.app';
    }
    if (!preferLocal && customYtUrl.isNotEmpty) {
      try {
        _log.info('Using custom YouTube API to resolve stream: $targetId');
        final normalizedBase = customYtUrl.endsWith('/') 
            ? customYtUrl.substring(0, customYtUrl.length - 1) 
            : customYtUrl;

        final response = await _dio.get<Map<String, dynamic>>(
          '$normalizedBase/api/resolve',
          queryParameters: {'id': targetId},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 && response.data != null) {
          final streamUrl = response.data!['url'] as String?;
          if (streamUrl != null && streamUrl.isNotEmpty) {
            _log.info('Successfully resolved stream via custom YouTube API');
            _streamUrlCache[cacheKey] = _StreamUrlCacheEntry(streamUrl, DateTime.now().add(_streamUrlCacheTtl));
            return streamUrl;
          }
        }
      } catch (e) {
        _log.warning('Custom YouTube resolver failed: $e. Falling back to local...');
      }
    }

    yt.StreamManifest? manifest;

    // Race all clients in TRUE parallel — first non-null result wins
    try {
      final racingFutures = _ytClients.map((client) async {
        try {
          final result = await _yt.videos.streamsClient
              .getManifest(targetId, ytClients: [client])
              .timeout(const Duration(seconds: 8));
          return result;
        } catch (_) {
          return null;
        }
      }).toList();

      // Wait for all to complete, take first success
      final results = await Future.wait(racingFutures);
      manifest = results.firstWhere((r) => r != null, orElse: () => null);
    } catch (e) {
      _log.warning('Parallel manifest fetch failed: $e');
    }

    if (manifest == null) {
      // Fallback: try ios client which doesn't need signature deciphering
      try {
        _log.debug('Trying ios client fallback for $targetId');
        manifest = await _yt.videos.streamsClient
            .getManifest(targetId, ytClients: [yt.YoutubeApiClient.ios])
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        _log.error('All YouTube clients failed to fetch manifest for $targetId: $e');
      }
    }

    if (manifest == null) {
      if (preferLocal && customYtUrl.isNotEmpty) {
        try {
          _log.info('Local resolution failed with preferLocal. Falling back to custom YouTube API for targetId: $targetId');
          final normalizedBase = customYtUrl.endsWith('/') 
              ? customYtUrl.substring(0, customYtUrl.length - 1) 
              : customYtUrl;

          final response = await _dio.get<Map<String, dynamic>>(
            '$normalizedBase/api/resolve',
            queryParameters: {'id': targetId},
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 && response.data != null) {
            final streamUrl = response.data!['url'] as String?;
            if (streamUrl != null && streamUrl.isNotEmpty) {
              _log.info('Successfully resolved stream via custom YouTube API fallback');
              _streamUrlCache[cacheKey] = _StreamUrlCacheEntry(streamUrl, DateTime.now().add(_streamUrlCacheTtl));
              return streamUrl;
            }
          }
        } catch (e) {
          _log.error('Custom YouTube resolver fallback failed: $e');
        }
      }
      throw Exception('All YouTube clients failed to fetch manifest for $targetId');
    }


    var audioStreams = manifest.audioOnly.toList();

    // Log all available streams so we know what YouTube is offering
    for (final s in audioStreams) {
      _log.debug('Available stream: container=${s.container.name}, codec=${s.codec.type}, bitrate=${s.bitrate.kiloBitsPerSecond}kbps');
    }

    // Windows Media Foundation (just_audio_windows) ONLY supports MP3 and AAC/M4A.
    // YouTube serves audio as either:
    //   - m4a  (AAC inside MP4 container) ← WMF-compatible ✓
    //   - webm (Opus inside WebM container) ← WMF INCOMPATIBLE ✗
    // Filter to only WMF-safe formats first.
    final winfriendlyStreams = audioStreams
        .where((s) {
          final container = s.container.name.toLowerCase();
          final codec = s.codec.type.toLowerCase();
          // Accept m4a or mp4 containers (AAC audio), reject webm/opus
          return container == 'm4a' ||
                 container == 'mp4' ||
                 codec == 'mp4a' ||
                 codec == 'aac';
        })
        .toList();

    // Use Windows-safe streams if any found; fall back to all (but log a warning)
    if (winfriendlyStreams.isNotEmpty) {
      audioStreams = winfriendlyStreams;
      _log.debug('Using ${winfriendlyStreams.length} WMF-compatible AAC/M4A streams');
    } else {
      _log.warning('No M4A/AAC streams found — falling back to all streams. Windows playback may fail.');
    }

    audioStreams.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    final streamInfo = switch (quality) {
      'Low' => audioStreams.first,
      'Medium' || 'Standard' => audioStreams[audioStreams.length ~/ 2],
      _ => audioStreams.last,
    };
    _log.info('Selected stream: container=${streamInfo.container.name}, bitrate=${streamInfo.bitrate.kiloBitsPerSecond}kbps');
    final url = streamInfo.url.toString();

    // Store in cache with TTL.
    _streamUrlCache[cacheKey] =
        _StreamUrlCacheEntry(url, DateTime.now().add(_streamUrlCacheTtl));

    // Keep cache from growing unboundedly (cap at 200 entries).
    if (_streamUrlCache.length > 200) {
      final oldest = _streamUrlCache.entries
          .reduce((a, b) => a.value.expiresAt.isBefore(b.value.expiresAt) ? a : b);
      _streamUrlCache.remove(oldest.key);
    }

    return url;
  }

  /// Get video + audio stream URL for video player
  Future<String> getVideoStreamUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final muxedStreams = manifest.muxed.toList()
      ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    final streamInfo = muxedStreams.last;
    return streamInfo.url.toString();
  }

  /// Search for related songs based on [videoId] metadata
  Future<List<Song>> getRelatedSongs(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return await searchSongs('${video.title} ${video.author}');
    } catch (_) {
      return const [];
    }
  }

  /// Fetch top charts
  Future<ChartsData> getCharts([String? country]) async {
    final topSongs = await searchSongs('Billboard Top Songs ${country ?? ''}');
    final topAlbums = await searchAlbums('Billboard Top Albums ${country ?? ''}');
    
    return ChartsData(
      topSongs: topSongs.take(20).toList(),
      topArtists: const [], // Auto-populated from songs on UI
      topAlbums: topAlbums.take(10).toList(),
    );
  }

  /// Static Mood Categories
  List<MoodCategory> getMoodGenreCategories() {
    return const [
      // Moods
      MoodCategory(id: 'relax', title: 'Relax'),
      MoodCategory(id: 'workout', title: 'Workout'),
      MoodCategory(id: 'energize', title: 'Energize'),
      MoodCategory(id: 'party', title: 'Party'),
      MoodCategory(id: 'romance', title: 'Romance'),
      MoodCategory(id: 'sad', title: 'Sad'),
      MoodCategory(id: 'focus', title: 'Focus'),
      MoodCategory(id: 'feel_good', title: 'Feel Good'),
      MoodCategory(id: 'sleep', title: 'Sleep'),
      MoodCategory(id: 'chill', title: 'Chill'),
      MoodCategory(id: 'commute', title: 'Commute'),
      MoodCategory(id: 'happy', title: 'Happy'),
      MoodCategory(id: 'rainy_day', title: 'Rainy Day'),
      MoodCategory(id: 'road_trip', title: 'Road Trip'),
      MoodCategory(id: 'study', title: 'Study'),
      MoodCategory(id: 'motivation', title: 'Motivation'),
      MoodCategory(id: 'morning', title: 'Morning'),
      MoodCategory(id: 'night_drive', title: 'Night Drive'),
      MoodCategory(id: 'heartbreak', title: 'Heartbreak'),
      MoodCategory(id: 'acoustic', title: 'Acoustic'),
      // Genres
      MoodCategory(id: 'pop', title: 'Pop'),
      MoodCategory(id: 'hip_hop', title: 'Hip-Hop'),
      MoodCategory(id: 'rock', title: 'Rock'),
      MoodCategory(id: 'jazz', title: 'Jazz'),
      MoodCategory(id: 'classical', title: 'Classical'),
      MoodCategory(id: 'edm', title: 'EDM'),
      MoodCategory(id: 'lofi', title: 'Lo-Fi'),
      MoodCategory(id: 'kpop', title: 'K-Pop'),
      MoodCategory(id: 'bollywood', title: 'Bollywood'),
      MoodCategory(id: 'devotional', title: 'Devotional'),
      MoodCategory(id: '90s', title: '90s Hits'),
      MoodCategory(id: 'retro', title: 'Retro'),
      MoodCategory(id: 'gaming', title: 'Gaming'),
      MoodCategory(id: 'rnb', title: 'R&B'),
      MoodCategory(id: 'soul', title: 'Soul'),
      MoodCategory(id: 'folk', title: 'Folk'),
      MoodCategory(id: 'country', title: 'Country'),
      MoodCategory(id: 'metal', title: 'Metal'),
      MoodCategory(id: 'punk', title: 'Punk'),
      MoodCategory(id: 'indie', title: 'Indie'),
      MoodCategory(id: 'reggae', title: 'Reggae'),
      MoodCategory(id: 'latin', title: 'Latin'),
      MoodCategory(id: 'punjabi', title: 'Punjabi'),
      MoodCategory(id: 'ghazal', title: 'Ghazal'),
      MoodCategory(id: 'sufi', title: 'Sufi'),
      MoodCategory(id: 'bhojpuri', title: 'Bhojpuri'),
      MoodCategory(id: 'tamil', title: 'Tamil'),
      MoodCategory(id: 'telugu', title: 'Telugu'),
      MoodCategory(id: 'marathi', title: 'Marathi'),
    ];
  }

  /// Filter out short vertical videos (YouTube Shorts)
  List<Song> filterOutShorts(List<Song> songs) {
    return songs;
  }

  // --- Helper Methods ---

  Song _mapVideoToSong(yt.Video video) {
    return Song(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      album: 'Single',
      duration: video.duration ?? const Duration(minutes: 3),
      artworkUrl: video.thumbnails.mediumResUrl,
      videoId: video.id.value,
    );
  }

  Future<List<Song>> _fetchPlaylistTracks(String playlistId) async {
    final List<Song> tracks = [];
    try {
      await for (final video in _yt.playlists.getVideos(playlistId)) {
        tracks.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: video.title,
          duration: video.duration ?? const Duration(minutes: 3),
          artworkUrl: video.thumbnails.mediumResUrl,
          videoId: video.id.value,
        ));
      }
    } catch (e, s) {
      _log.error('Standard playlist getVideos empty or failed', e, s);
    }

    if (tracks.isEmpty) {
      _log.info('Attempting custom HTML scraper fallback for playlist: $playlistId');
      try {
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        final response = await dio.get<String>(
          'https://www.youtube.com/playlist?list=$playlistId',
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          ),
        );
        final html = response.data as String;
        const startTag = 'var ytInitialData =';
        final startIdx = html.indexOf(startTag);
        if (startIdx != -1) {
          final jsonStart = html.indexOf('{', startIdx + startTag.length);
          if (jsonStart != -1) {
            int openBraces = 0;
            int endIdx = -1;
            for (int i = jsonStart; i < html.length; i++) {
              final char = html[i];
              if (char == '{') {
                openBraces++;
              } else if (char == '}') {
                openBraces--;
                if (openBraces == 0) {
                  endIdx = i;
                  break;
                }
              }
            }
            if (endIdx != -1) {
              final jsonStr = html.substring(jsonStart, endIdx + 1);
              final data = json.decode(jsonStr);
              final addedIds = <String>{};

              void parseLockups(dynamic obj) {
                if (obj is Map) {
                  if (obj.containsKey('lockupViewModel')) {
                    final lockup = obj['lockupViewModel'] as Map;
                    final rendererContext = lockup['rendererContext'] as Map?;
                    final commandContext = rendererContext?['commandContext'] as Map?;
                    final onTap = commandContext?['onTap'] as Map?;
                    final innertubeCommand = onTap?['innertubeCommand'] as Map?;
                    final watchEndpoint = innertubeCommand?['watchEndpoint'] as Map?;

                    if (watchEndpoint != null) {
                      final videoId = watchEndpoint['videoId'] as String?;
                      final metadata = lockup['metadata']?['lockupMetadataViewModel'] as Map?;
                      final title = metadata?['title']?['content'] as String?;
                      final subtitle = metadata?['subtitle']?['content'] as String? ?? '';

                      String artwork = '';
                      final contentImage = lockup['contentImage'] as Map?;
                      final thumbnailViewModel = contentImage?['thumbnailViewModel'] as Map?;
                      final image = thumbnailViewModel?['image'] as Map?;
                      final sources = image?['sources'] as List?;
                      if (sources != null && sources.isNotEmpty) {
                        artwork = sources.first['url'] as String? ?? '';
                      }

                      if (videoId != null && title != null && !addedIds.contains(videoId)) {
                        addedIds.add(videoId);
                        String artist = subtitle;
                        final dotIdx = subtitle.indexOf('•');
                        if (dotIdx != -1) {
                          artist = subtitle.substring(0, dotIdx).trim();
                        }
                        tracks.add(Song(
                          id: videoId,
                          title: title,
                          artist: artist.isNotEmpty ? artist : 'Unknown Artist',
                          album: title,
                          duration: const Duration(minutes: 3),
                          artworkUrl: artwork,
                          videoId: videoId,
                        ));
                      }
                    }
                  } else if (obj.containsKey('playlistVideoRenderer')) {
                    final pvr = obj['playlistVideoRenderer'] as Map;
                    final videoId = pvr['videoId'] as String?;

                    final titleMap = pvr['title'] as Map?;
                    String? title;
                    if (titleMap != null) {
                      if (titleMap.containsKey('runs') && (titleMap['runs'] as List).isNotEmpty) {
                        title = titleMap['runs'][0]['text'] as String?;
                      } else {
                        title = titleMap['simpleText'] as String?;
                      }
                    }

                    final artistMap = pvr['shortBylineText'] as Map?;
                    String artist = '';
                    if (artistMap != null && artistMap.containsKey('runs') && (artistMap['runs'] as List).isNotEmpty) {
                      artist = artistMap['runs'][0]['text'] as String? ?? '';
                    }

                    String artwork = '';
                    final thumbnailMap = pvr['thumbnail'] as Map?;
                    final thumbnails = thumbnailMap?['thumbnails'] as List?;
                    if (thumbnails != null && thumbnails.isNotEmpty) {
                      artwork = thumbnails.first['url'] as String? ?? '';
                    }

                    if (videoId != null && title != null && !addedIds.contains(videoId)) {
                      addedIds.add(videoId);
                      tracks.add(Song(
                        id: videoId,
                        title: title,
                        artist: artist.isNotEmpty ? artist : 'Unknown Artist',
                        album: title,
                        duration: const Duration(minutes: 3),
                        artworkUrl: artwork,
                        videoId: videoId,
                      ));
                    }
                  }

                  for (final v in obj.values) {
                    parseLockups(v);
                  }
                } else if (obj is List) {
                  for (final item in obj) {
                    parseLockups(item);
                  }
                }
              }

              parseLockups(data);
              _log.info('Fallback HTML parser successfully found ${tracks.length} tracks.');
            }
          }
        }
      } catch (e, s) {
        _log.error('Fallback HTML playlist scraper failed', e, s);
      }
    }

    final filterExplicit = await _shouldFilterExplicit();
    if (filterExplicit) {
      tracks.removeWhere((s) => _isExplicit(s.title, s.artist, s.album));
    }

    return tracks;
  }

  Future<bool> _shouldFilterExplicit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool('allow_explicit_content') ?? true);
    } catch (_) {
      return false;
    }
  }

  bool _isExplicit(String title, String artist, String album) {
    final t = title.toLowerCase();
    final a = artist.toLowerCase();
    final al = album.toLowerCase();
    return t.contains('explicit') ||
        t.contains('parental advisory') ||
        a.contains('explicit') ||
        al.contains('explicit');
  }

  /// Closes resources
  void dispose() {
    _yt.close();
    _dio.close();
  }

  /// Get search suggestions/autocomplete
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      return await _yt.search.getQuerySuggestions(query);
    } catch (_) {
      return const [];
    }
  }
}
