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

final youtubeMusicRemoteSourceProvider = Provider<YouTubeMusicRemoteSource>((ref) {
  final source = YouTubeMusicRemoteSource();
  ref.onDispose(() => source.dispose());
  return source;
});

class YouTubeMusicRemoteSource {
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final _log = AppLogger('YouTubeMusicRemoteSource');

  /// Search for songs matching [query]
  Future<List<Song>> searchSongs(String query, {List<String>? filters}) async {
    final searchList = await _yt.search.search('$query song');
    final songs = <Song>[];

    for (final item in searchList) {
      songs.add(_mapVideoToSong(item));
    }

    return filterOutShorts(songs);
  }

  /// Search for albums matching [query]
  Future<List<Album>> searchAlbums(String query) async {
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

  static const _kCacheDateKey = 'home_feed_cache_date';

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
            _log.debug('Loaded home feed from daily cache ($key).');
            return _homeDataFromJson(decoded);
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

    // New Rich Sections
    List<Album> featuredPlaylistsForYou = [];
    List<Song> indianMusic = [];
    List<Song> forgottenFavorites = [];
    List<Album> albumsForYou = [];

    await Future.wait([
      searchSongs('popular hits$langSuffix').then((v) => quickPicks = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching quick picks', e, s);
        return <Song>[];
      }),
      searchAlbums('latest albums 2026$langSuffix').then((v) => newReleases = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching new releases', e, s);
        return <Album>[];
      }),
      searchSongs('trending music$langSuffix').then((v) => charts = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching charts', e, s);
        return <Song>[];
      }),
      searchSongs('top songs 2025$langSuffix').then((v) => listenAgain = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching listen again', e, s);
        return <Song>[];
      }),
      searchArtists('popular artists$langSuffix').then((v) => recommendedArtists = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching artists', e, s);
        return <Artist>[];
      }),
      searchAlbums('best playlist 2025$langSuffix').then((albums) {
        if (albums.isNotEmpty) featuredPlaylist = albums.first;
      }).catchError((Object e, StackTrace s) {
        _log.error('Error fetching featured playlist', e, s);
        return null;
      }),
      // New rich section fetches
      searchAlbums('featured playlist$langSuffix').then((v) => featuredPlaylistsForYou = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching featured playlists for you', e, s);
        return <Album>[];
      }),
      searchSongs('bollywood hits$langSuffix').then((v) => indianMusic = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching Indian music', e, s);
        return <Song>[];
      }),
      searchSongs('retro classics 90s$langSuffix').then((v) => forgottenFavorites = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching forgotten favorites', e, s);
        return <Song>[];
      }),
      searchAlbums('pop albums$langSuffix').then((v) => albumsForYou = v).catchError((Object e, StackTrace s) {
        _log.error('Error fetching albums for you', e, s);
        return <Album>[];
      }),
    ]);

    if (quickPicks.isEmpty && newReleases.isEmpty && charts.isEmpty) {
      try {
        quickPicks = await searchSongs('popular hits');
        newReleases = await searchAlbums('latest albums 2026');
        charts = await searchSongs('trending music');
      } catch (e, s) {
        _log.error('Generic fallback searches also failed', e, s);
      }
    }

    final homeData = HomeData(
      quickPicks: quickPicks.take(20).toList(),
      newReleases: newReleases.take(12).toList(),
      charts: charts.take(20).toList(),
      moods: moods,
      listenAgain: listenAgain.take(12).toList(),
      recommendedArtists: recommendedArtists.take(8).toList(),
      featuredPlaylist: featuredPlaylist,
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
    final playlist = await _yt.playlists.get(albumId);
    final List<Song> tracks = await _fetchPlaylistTracks(albumId);

    return Album(
      id: playlist.id.value,
      title: playlist.title,
      artist: playlist.author,
      artworkUrl: playlist.thumbnails.mediumResUrl,
      year: null,
      tracks: tracks,
      songCount: tracks.length,
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
    final playlist = await _yt.playlists.get(playlistId);
    final List<Song> tracks = await _fetchPlaylistTracks(playlistId);

    return Playlist(
      id: playlist.id.value,
      title: playlist.title,
      description: playlist.description,
      artworkUrl: playlist.thumbnails.mediumResUrl,
      trackCount: tracks.length,
      songs: tracks,
      isYouTube: true,
      isLocal: false,
    );
  }

  /// Get high-quality stream URL for playback
  Future<String> getStreamUrl(String videoId, String quality) async {
    final manifest = await _yt.videos.streamsClient.getManifest(
      videoId,
      ytClients: [yt.YoutubeApiClient.androidVr],
    );
    var audioStreams = manifest.audioOnly.toList();
    
    // Filter to only MP4 (AAC) streams for universal hardware decoding compatibility (especially on Windows)
    final mp4Streams = audioStreams.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
    if (mp4Streams.isNotEmpty) {
      audioStreams = mp4Streams;
    }

    audioStreams.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    
    final streamInfo = quality == 'Low' ? audioStreams.first : audioStreams.last;
    return streamInfo.url.toString();
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
    return songs.where((song) => song.duration.inSeconds >= 60).toList();
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
        final dio = Dio();
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

    return tracks;
  }

  /// Closes resources
  void dispose() {
    _yt.close();
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
