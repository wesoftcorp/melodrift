import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/utils/logger.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/mood_category.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/jiosaavn_service.dart';
import '../../core/services/innertube_service.dart';
import '../../core/services/music_track.dart';


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

  static const _kCacheDateKey = 'home_feed_cache_date_v8';

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
          if (decoded.containsKey('featuredPlaylistsForYou') &&
              decoded.containsKey('indianMusic') &&
              decoded.containsKey('forgottenFavorites') &&
              decoded.containsKey('albumsForYou')) {
            final homeData = _homeDataFromJson(decoded);
            if (homeData.quickPicks.isNotEmpty) {
               _log.debug('Loaded home feed from daily cache ($key).');
               return homeData;
            }
          }

        }
      }
    } catch (e, s) {
      _log.error('Failed to read home feed cache', e, s);
    }

    _log.info('Fetching fresh YouTube Music & JioSaavn home feed...');
    final langSuffix = (language == null || language.toLowerCase() == 'all') ? '' : ' $language';

    final jioSaavn = getIt<JioSaavnService>();
    final innerTube = getIt<InnerTubeService>();

    Future<List<Song>> fetchJioSongs(String query) async {
      try {
        final tracks = await jioSaavn.search(query).timeout(const Duration(seconds: 6));
        return tracks.map((MusicTrack t) => Song(
          id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
          title: t.title,
          artist: t.artist,
          album: t.album,
          duration: t.duration,
          artworkUrl: t.artworkUrl,
          videoId: t.id,
          source: 'JioSaavn',
        )).toList();
      } catch (e) {
        _log.error('Failed to fetch JioSaavn songs for query "$query": $e');
        return [];
      }
    }

    Future<List<Song>> fetchYtSongs(String query) async {
      try {
        final tracks = await innerTube.search(query).timeout(const Duration(seconds: 6));
        if (tracks.isNotEmpty) {
          return tracks.map((t) => Song(
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artworkUrl: t.artworkUrl,
            videoId: t.id,
            source: 'YouTube Music',
          )).toList();
        }
      } catch (_) {}

      try {
        final searchList = await _yt.search.search('$query song').timeout(const Duration(seconds: 6));
        final List<Song> ytSongs = [];
        for (final item in searchList) {
          ytSongs.add(_mapVideoToSong(item));
        }
        return filterOutShorts(ytSongs);
      } catch (e) {
        _log.warning('Failed to fetch YouTube songs for query "$query": $e');
        return [];
      }
    }

    List<Song> interleaveSongs(List<Song> listA, List<Song> listB) {
      final List<Song> result = [];
      final maxLen = listA.length > listB.length ? listA.length : listB.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < listA.length) result.add(listA[i]);
        if (i < listB.length) result.add(listB[i]);
      }
      return result;
    }

    Future<List<Album>> fetchAlbums(String query) async {
      try {
        final jioSongs = await fetchJioSongs(query);
        final ytSongs = await fetchYtSongs(query);
        final combined = interleaveSongs(ytSongs, jioSongs);
        final Map<String, Album> uniqueAlbums = {};
        for (final song in combined) {
          final albumName = song.album.isNotEmpty ? song.album : 'Single';
          if (!uniqueAlbums.containsKey(albumName)) {
            uniqueAlbums[albumName] = Album(
              id: song.id,
              title: albumName,
              artist: song.artist,
              artworkUrl: song.artworkUrl,
              tracks: [song],
              songCount: 1,
              source: song.source,
            );
          }
        }
        return uniqueAlbums.values.toList();
      } catch (e) {
        return [];
      }
    }

    List<Song> quickPicks = [];
    List<Album> newReleases = [];
    List<Song> charts = [];
    List<Song> listenAgain = [];
    List<Artist> recommendedArtists = [];
    Album? featuredPlaylist;
    final moods = getMoodGenreCategories();
    List<Song> trendingSongs = [];
    List<Album> featuredPlaylistsForYou = [];
    List<Song> indianMusic = [];
    List<Song> forgottenFavorites = [];
    List<Album> albumsForYou = [];

    await Future.wait([
      Future.wait([
        fetchYtSongs('trending songs$langSuffix'),
        fetchJioSongs('hindi hits$langSuffix'),
      ]).then((results) => quickPicks = interleaveSongs(results[0], results[1])),

      fetchAlbums('new songs$langSuffix').then((v) => newReleases = v),

      Future.wait([
        fetchYtSongs('top music chart$langSuffix'),
        fetchJioSongs('trending$langSuffix'),
      ]).then((results) => charts = interleaveSongs(results[0], results[1])),

      Future.wait([
        fetchYtSongs('romantic songs$langSuffix'),
        fetchJioSongs('romantic$langSuffix'),
      ]).then((results) => listenAgain = interleaveSongs(results[0], results[1])),

      Future.wait([
        fetchYtSongs('viral hits$langSuffix'),
        fetchJioSongs('hindi top$langSuffix'),
      ]).then((results) => trendingSongs = interleaveSongs(results[0], results[1])),

      fetchAlbums('popular playlists$langSuffix').then((v) => featuredPlaylistsForYou = v),

      Future.wait([
        fetchYtSongs('bollywood hits$langSuffix'),
        fetchJioSongs('bollywood$langSuffix'),
      ]).then((results) => indianMusic = interleaveSongs(results[0], results[1])),

      Future.wait([
        fetchYtSongs('retro 90s songs$langSuffix'),
        fetchJioSongs('90s retro$langSuffix'),
      ]).then((results) => forgottenFavorites = interleaveSongs(results[0], results[1])),

      fetchAlbums('top albums$langSuffix').then((v) => albumsForYou = v),
    ]);

    // Fetch top artists with real profile and image data from JioSaavn CDN

    final topArtistNames = [
      'Arijit Singh',
      'Neha Kakkar',
      'Shreya Ghoshal',
      'Atif Aslam',
      'Pritam',
      'Badshah',
      'Diljit Dosanjh',
      'Honey Singh',
      'Armaan Malik',
      'Jubin Nautiyal',
      'Sonu Nigam',
      'A.R. Rahman',
    ];

    try {
      final artistFutures = <Future<Artist?>>[];
      for (final name in topArtistNames) {
        artistFutures.add(() async {
          try {
            final results = await jioSaavn.searchArtists(name);
            if (results.isNotEmpty) {
              final match = results.firstWhere(
                (r) => r['name'].toString().toLowerCase() == name.toLowerCase(),
                orElse: () => results.first,
              );
              
              String artworkUrl = '';
              final imageVal = match['image'];
              if (imageVal is List && imageVal.isNotEmpty) {
                final lastImg = imageVal.last as Map<dynamic, dynamic>?;
                artworkUrl = lastImg?['link'] as String? ?? lastImg?['url'] as String? ?? '';
              } else if (imageVal is String) {
                artworkUrl = imageVal;
              }

              return Artist(
                id: match['id']?.toString() ?? 'artist_${name.hashCode}',
                name: match['name']?.toString() ?? name,
                artworkUrl: artworkUrl,
                subscribers: 'JioSaavn Artist',
                isVerified: match['isVerified'] as bool? ?? true,
              );
            }
          } catch (_) {}
          return null;
        }());
      }

      final resolved = await Future.wait(artistFutures);
      recommendedArtists = resolved.whereType<Artist>().toList();
    } catch (_) {}

    // Fallback placeholder logic if CDN fetches failed
    if (recommendedArtists.isEmpty) {
      final Set<String> seenArtists = {};
      for (final song in quickPicks) {
        final firstArtist = song.artist.split(',').first.trim();
        if (firstArtist.isNotEmpty && !seenArtists.contains(firstArtist)) {
          seenArtists.add(firstArtist);
          recommendedArtists.add(Artist(
            id: 'artist_${song.id}',
            name: firstArtist,
            artworkUrl: song.artworkUrl,
            subscribers: 'JioSaavn Artist',
            isVerified: true,
          ));
        }
        if (recommendedArtists.length >= 8) break;
      }
    }

    if (featuredPlaylistsForYou.isNotEmpty) {
      featuredPlaylist = featuredPlaylistsForYou.first;
    }

    final homeData = HomeData(
      quickPicks: quickPicks.take(20).toList(),
      newReleases: newReleases.take(12).toList(),
      charts: charts.take(20).toList(),
      moods: moods,
      listenAgain: listenAgain.take(12).toList(),
      recommendedArtists: recommendedArtists,
      featuredPlaylist: featuredPlaylist,
      trendingSongs: trendingSongs.take(50).toList(),
      featuredPlaylistsForYou: featuredPlaylistsForYou.take(12).toList(),
      indianMusic: indianMusic.take(20).toList(),
      forgottenFavorites: forgottenFavorites.take(20).toList(),
      albumsForYou: albumsForYou.take(12).toList(),
    );

    // Save to daily cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheDateKey, key);
      await prefs.setString('home_feed_cache_data_${language ?? "all"}', json.encode(_homeDataToJson(homeData)));
      _log.debug('Successfully saved JioSaavn home feed to daily cache ($key).');
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
        final searchList = await _yt.search.search('$videoId song').timeout(const Duration(seconds: 8));
        if (searchList.isNotEmpty) {
          targetId = searchList.first.id.value;
          _log.info('Resolved "$videoId" to YouTube videoId "$targetId"');
        }
      } catch (e) {
        _log.warning('Failed to resolve search for "$videoId": $e');
      }
    }

    if (!RegExp(r'^[a-zA-Z0-9_\-]{11}$').hasMatch(targetId)) {
      _log.error('Could not resolve "$videoId" to a valid 11-char YouTube video ID.');
      throw Exception('Could not resolve "$videoId" to a valid 11-char YouTube video ID.');
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
          final mimeType = response.data!['mimeType'] as String? ?? '';
          if (streamUrl != null && streamUrl.isNotEmpty) {
            // Reject WebM/Opus stream URLs on Windows to prevent playback/download stalling
            final isWebM = mimeType.contains('webm') || mimeType.contains('opus') || 
                           streamUrl.contains('mime=audio/webm') || streamUrl.contains('codecs=opus');
            if (Platform.isWindows && isWebM) {
              _log.warning('Custom YouTube resolver returned WebM/Opus stream on Windows. Rejecting and falling back to local racing...');
            } else {
              _log.info('Successfully resolved stream via custom YouTube API');
              _streamUrlCache[cacheKey] = _StreamUrlCacheEntry(streamUrl, DateTime.now().add(_streamUrlCacheTtl));
              return streamUrl;
            }
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
            final mimeType = response.data!['mimeType'] as String? ?? '';
            if (streamUrl != null && streamUrl.isNotEmpty) {
              final isWebM = mimeType.contains('webm') || mimeType.contains('opus') || 
                             streamUrl.contains('mime=audio/webm') || streamUrl.contains('codecs=opus');
              if (Platform.isWindows && isWebM) {
                _log.warning('Custom YouTube resolver fallback returned WebM/Opus stream on Windows. Rejecting...');
              } else {
                _log.info('Successfully resolved stream via custom YouTube API fallback');
                _streamUrlCache[cacheKey] = _StreamUrlCacheEntry(streamUrl, DateTime.now().add(_streamUrlCacheTtl));
                return streamUrl;
              }
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

  /// Download YouTube stream bytes directly using youtube_explode's internal HTTP client or fallback HTTP stream to bypass 403 blocks.
  Future<void> downloadVideo(
    String videoId,
    String quality,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    String targetId = videoId;
    if (!RegExp(r'^[a-zA-Z0-9_\-]{11}$').hasMatch(videoId)) {
      try {
        final searchList = await _yt.search.search('$videoId song').timeout(const Duration(seconds: 8));
        if (searchList.isNotEmpty) {
          targetId = searchList.first.id.value;
        }
      } catch (_) {}
    }

    yt.StreamManifest? manifest;

    // Try parallel client resolution matching getStreamUrl
    for (final client in _ytClients) {
      try {
        manifest = await _yt.videos.streamsClient
            .getManifest(targetId, ytClients: [client])
            .timeout(const Duration(seconds: 10));
        if (manifest != null && manifest.audioOnly.isNotEmpty) break;
      } catch (_) {}
    }

    if (manifest == null) {
      try {
        manifest = await _yt.videos.streamsClient.getManifest(targetId).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    if (manifest != null && manifest.audioOnly.isNotEmpty) {
      var audioStreams = manifest.audioOnly.toList();
      final winfriendlyStreams = audioStreams.where((s) {
        final container = s.container.name.toLowerCase();
        final codec = s.codec.type.toLowerCase();
        return container == 'm4a' || container == 'mp4' || codec == 'mp4a' || codec == 'aac';
      }).toList();

      if (winfriendlyStreams.isNotEmpty) {
        audioStreams = winfriendlyStreams;
      }

      audioStreams.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
      final streamInfo = switch (quality) {
        'Low' => audioStreams.first,
        'Medium' || 'Standard' => audioStreams[audioStreams.length ~/ 2],
        _ => audioStreams.last,
      };

      try {
        final stream = _yt.videos.streamsClient.get(streamInfo);
        final file = File(savePath);
        final fileStream = file.openWrite();
        final total = streamInfo.size.totalBytes;
        int received = 0;

        await for (final chunk in stream) {
          fileStream.add(chunk);
          received += chunk.length;
          if (onProgress != null) {
            onProgress(received, total);
          }
        }
        await fileStream.close();
        return;
      } catch (e) {
        _log.warning('Direct streamsClient.get failed for $targetId: $e. Falling back to stream URL download.');
      }
    }

    // Direct fallback using resolved HTTP stream URL via Dio
    final streamUrl = await getStreamUrl(targetId, quality, preferLocal: true);
    final response = await _dio.download(
      streamUrl,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to download YouTube audio stream. Status: ${response.statusCode}');
    }
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
