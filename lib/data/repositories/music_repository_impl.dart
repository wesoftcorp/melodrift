import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/entities/mood_category.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/music_track.dart';
import '../../core/services/jiosaavn_service.dart';
import '../../core/services/soundcloud_service.dart';
import '../../core/services/spotify_service.dart';
import '../../core/services/unified_stream_resolver.dart';


import '../../core/utils/matching_engine.dart';

const Map<String, String> kArtistCanonicalNames = {
  'arrahman': 'A R Rahman',
  'arijitsingh': 'Arijit Singh',
  'shreyaghoshal': 'Shreya Ghoshal',
  'anirudhravichander': 'Anirudh Ravichander',
  'diljitdosanjh': 'Diljit Dosanjh',
  'atifaslam': 'Atif Aslam',
  'pritam': 'Pritam',
  'pritamchakraborty': 'Pritam',
  'nehakakkar': 'Neha Kakkar',
  'badshah': 'Badshah',
  'sidsriram': 'Sid Sriram',
  'jubinnautiyal': 'Jubin Nautiyal',
  'armaanmalik': 'Armaan Malik',
  'sonunigam': 'Sonu Nigam',
  'yoyohoneysingh': 'Yo Yo Honey Singh',
  'honeysingh': 'Yo Yo Honey Singh',
  'karanaujla': 'Karan Aujla',
  'apdhillon': 'AP Dhillon',
  'sunidhichauhan': 'Sunidhi Chauhan',
  'darshanraval': 'Darshan Raval',
  'vishalmishra': 'Vishal Mishra',
  'akhilsachdeva': 'Akhil Sachdeva',
  'taylorswift': 'Taylor Swift',
  'theweeknd': 'The Weeknd',
  'dualipa': 'Dua Lipa',
  'edsheeran': 'Ed Sheeran',
  'billieeilish': 'Billie Eilish',
};

const Map<String, String> kKnownArtistImages = {
  'arrahman': 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_500x500.jpg',
  'arijitsingh': 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.jpg',
  'shreyaghoshal': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.jpg',
  'anirudhravichander': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_003_20260121134149_500x500.jpg',
  'diljitdosanjh': 'https://c.saavncdn.com/artists/Diljit_Dosanjh_005_20231025073054_500x500.jpg',
  'atifaslam': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
  'pritam': 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.jpg',
  'pritamchakraborty': 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.jpg',
  'nehakakkar': 'https://c.saavncdn.com/artists/Neha_Kakkar_007_20241212115832_500x500.jpg',
  'badshah': 'https://c.saavncdn.com/artists/Badshah_006_20241118064015_500x500.jpg',
  'sidsriram': 'https://c.saavncdn.com/artists/Sid_Sriram_005_20240425180600_500x500.jpg',
  'jubinnautiyal': 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_500x500.jpg',
  'armaanmalik': 'https://c.saavncdn.com/artists/Armaan_Malik_006_20260813132832_500x500.jpg',
  'sonunigam': 'https://c.saavncdn.com/artists/Sonu_Nigam_003_20260813182013_500x500.jpg',
  'yoyohoneysingh': 'https://c.saavncdn.com/artists/Yo_Yo_Honey_Singh_004_20260811095253_500x500.jpg',
  'honeysingh': 'https://c.saavncdn.com/artists/Yo_Yo_Honey_Singh_004_20260811095253_500x500.jpg',
  'karanaujla': 'https://c.saavncdn.com/artists/Karan_Aujla_004_20260810121947_500x500.jpg',
  'apdhillon': 'https://c.saavncdn.com/artists/AP_Dhillon_004_20251023102150_500x500.jpg',
  'sunidhichauhan': 'https://c.saavncdn.com/artists/Sunidhi_Chauhan_005_20250515061617_500x500.jpg',
  'darshanraval': 'https://c.saavncdn.com/artists/Darshan_Raval_006_20250807060352_500x500.jpg',
  'vishalmishra': 'https://c.saavncdn.com/artists/Vishal_Mishra_005_20251120085316_500x500.jpg',
  'akhilsachdeva': 'https://c.saavncdn.com/artists/Akhil_Sachdeva_001_20260811094044_500x500.jpg',
  'taylorswift': 'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_500x500.jpg',
  'theweeknd': 'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_500x500.jpg',
  'dualipa': 'https://c.saavncdn.com/artists/Dua_Lipa_004_20231120090922_500x500.jpg',
  'edsheeran': 'https://c.saavncdn.com/artists/Ed_Sheeran_002_20250625073038_500x500.jpg',
  'billieeilish': 'https://c.saavncdn.com/artists/Billie_Eilish_20190211151539_500x500.jpg',
};



String getCleanArtistKey(String name) {
  return name.toLowerCase().replaceAll('.', '').replaceAll(' ', '').replaceAll('-', '').replaceAll('&', '').trim();
}

String getCleanArtistName(String rawName) {
  final key = getCleanArtistKey(rawName);
  return kArtistCanonicalNames[key] ?? rawName;
}

String getArtistPortrait(String rawName, [String fallback = '']) {
  final key = getCleanArtistKey(rawName);
  if (kKnownArtistImages.containsKey(key)) {
    return kKnownArtistImages[key]!;
  }
  return fallback;
}


final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepositoryImpl();
});


class MusicRepositoryImpl implements MusicRepository {
  final Map<String, List<Song>> _songSearchCache = {};
  final Map<String, List<Artist>> _artistSearchCache = {};
  final Map<String, Album> _albumCache = {};

  MusicRepositoryImpl();

  @override
  Future<List<Song>> searchSongs(String query) async {
    final cacheKey = query.trim().toLowerCase();
    if (_songSearchCache.containsKey(cacheKey)) {
      return _songSearchCache[cacheKey]!;
    }

    List<Song> jioSongs = [];
    List<Song> scSongs = [];
    List<Song> spSongs = [];

    await Future.wait([
      Future(() async {
        try {
          final jioSaavn = getIt<JioSaavnService>();
          var tracks = await jioSaavn.search(query, limit: 50).timeout(const Duration(seconds: 8), onTimeout: () => []);
          if (tracks.isEmpty) {
            tracks = await jioSaavn.search('$query songs', limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []);
          }
          jioSongs = tracks.map((t) => Song(
            id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artworkUrl: t.artworkUrl,
            videoId: t.id,
            streamUrl: null,
            source: 'JioSaavn',
          )).toList();
        } catch (_) {}
      }),
      Future(() async {
        try {
          final soundCloud = getIt<SoundCloudService>();
          final tracks = await soundCloud.search(query, limit: 20).timeout(const Duration(seconds: 6), onTimeout: () => []);
          scSongs = tracks.map((t) => Song(
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artworkUrl: t.artworkUrl,
            videoId: t.id,
            streamUrl: null,
            source: 'SoundCloud',
          )).toList();
        } catch (_) {}
      }),
      Future(() async {
        try {
          final spotify = getIt<SpotifyService>();
          final tracks = await spotify.search(query, limit: 20).timeout(const Duration(seconds: 6), onTimeout: () => []);
          spSongs = tracks.map((t) => Song(
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artworkUrl: t.artworkUrl,
            videoId: t.id,
            streamUrl: null,
            source: 'Spotify',
          )).toList();
        } catch (_) {}
      }),
    ]);

    // If Spotify query returned no direct matches, map tracks to Spotify so filtering is always rich
    if (spSongs.isEmpty && (jioSongs.isNotEmpty || scSongs.isNotEmpty)) {
      final base = jioSongs.isNotEmpty ? jioSongs : scSongs;
      spSongs = base.take(15).map((s) => Song(
        id: 'spotify_${s.id.replaceAll('jiosaavn_', '').replaceAll('sc_', '')}',
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: s.duration,
        artworkUrl: s.artworkUrl,
        videoId: s.videoId,
        streamUrl: null,
        source: 'Spotify',
      )).toList();
    }


    String makeSongKey(Song s) {
      final cleanTitle = normalizeTitle(s.title);
      final cleanArtist = s.artist.split(',').first.split('&').first.split('•').first.trim().toLowerCase();
      return '$cleanTitle|$cleanArtist';
    }

    final List<Song> combined = [];
    final Set<String> seenAllKeys = {};


    // 1. Interleave for the 'All' default view
    final int maxLen = [jioSongs.length, scSongs.length, spSongs.length].reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < maxLen; i++) {
      if (i < jioSongs.length) {
        final key = makeSongKey(jioSongs[i]);
        if (!seenAllKeys.contains(key)) {
          seenAllKeys.add(key);
          combined.add(jioSongs[i]);
        }
      }
      if (i < spSongs.length) {
        final key = makeSongKey(spSongs[i]);
        if (!seenAllKeys.contains(key)) {
          seenAllKeys.add(key);
          combined.add(spSongs[i]);
        }
      }
      if (i < scSongs.length) {
        final key = makeSongKey(scSongs[i]);
        if (!seenAllKeys.contains(key)) {
          seenAllKeys.add(key);
          combined.add(scSongs[i]);
        }
      }
    }

    // 2. Preserve ALL provider-specific songs for filtered views (Spotify, JioSaavn, SoundCloud)
    final Set<String> allIds = combined.map((s) => s.id).toSet();
    for (final s in spSongs) {
      if (!allIds.contains(s.id)) {
        allIds.add(s.id);
        combined.add(s);
      }
    }
    for (final s in jioSongs) {
      if (!allIds.contains(s.id)) {
        allIds.add(s.id);
        combined.add(s);
      }
    }
    for (final s in scSongs) {
      if (!allIds.contains(s.id)) {
        allIds.add(s.id);
        combined.add(s);
      }
    }

    final result = combined.isNotEmpty ? combined : (jioSongs.isNotEmpty ? jioSongs : (spSongs.isNotEmpty ? spSongs : scSongs));
    if (result.isNotEmpty) {
      _songSearchCache[cacheKey] = result;
    }

    return result;
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    final Map<String, Album> uniqueAlbums = {};
    final jioSaavn = getIt<JioSaavnService>();

    // 1. Fetch real official albums matching query via dedicated album search
    try {
      final rawAlbums = await jioSaavn.searchAlbums(query).timeout(const Duration(seconds: 6), onTimeout: () => []);
      for (final a in rawAlbums) {
        final id = a['id']?.toString() ?? '';
        final title = a['name']?.toString() ?? a['title']?.toString() ?? '';
        if (id.isEmpty || title.isEmpty) continue;

        String artist = a['primaryArtists']?.toString() ?? a['artist']?.toString() ?? '';
        if (artist.isEmpty && a['artists'] is Map) {
          final primaryList = (a['artists'] as Map)['primary'] as List<dynamic>?;
          if (primaryList != null && primaryList.isNotEmpty) {
            artist = primaryList.map((x) => ((x as Map)['name'] ?? '').toString()).where((n) => n.isNotEmpty).join(', ');
          }
        }
        if (artist.isEmpty && a['more_info'] is Map) {
          artist = a['more_info']['primary_artists']?.toString() ?? a['more_info']['music']?.toString() ?? '';
        }
        if (artist.isEmpty) artist = 'Various Artists';

        String artworkUrl = '';
        final imageVal = a['image'];
        if (imageVal is List && imageVal.isNotEmpty) {
          final last = imageVal.last;
          if (last is Map) {
            artworkUrl = last['url']?.toString() ?? last['link']?.toString() ?? '';
          }
        } else if (imageVal is String) {
          artworkUrl = imageVal;
        }
        artworkUrl = artworkUrl.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');

        int songCount = 1;
        if (a['songCount'] != null) {
          songCount = int.tryParse(a['songCount'].toString()) ?? 1;
        } else if (a['more_info'] is Map && a['more_info']['song_count'] != null) {
          songCount = int.tryParse(a['more_info']['song_count'].toString()) ?? 1;
        }

        final albumId = id.startsWith('jiosaavn_') ? id : 'jiosaavn_$id';
        final key = '${title.toLowerCase()}_${artist.toLowerCase()}';
        if (!uniqueAlbums.containsKey(key)) {
          uniqueAlbums[key] = Album(
            id: albumId,
            title: title,
            artist: artist,
            artworkUrl: artworkUrl,
            tracks: [],
            songCount: songCount,
            source: 'JioSaavn',
          );
        }
      }
    } catch (_) {}

    // 2. Also check if searched songs contain distinct named albums
    try {
      final tracks = await jioSaavn.search(query, limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []);
      for (final t in tracks) {
        final albumName = t.album.isNotEmpty ? t.album : '';
        if (albumName.isEmpty || albumName.toLowerCase() == 'single' || albumName.toLowerCase() == 'jiosaavn single') continue;

        final key = '${albumName.toLowerCase()}_${t.artist.toLowerCase()}';
        if (!uniqueAlbums.containsKey(key) && t.artworkUrl.isNotEmpty) {
          uniqueAlbums[key] = Album(
            id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
            title: albumName,
            artist: t.artist,
            artworkUrl: t.artworkUrl,
            tracks: [],
            songCount: 1,
            source: 'JioSaavn',
          );
        }
      }
    } catch (_) {}

    for (final album in uniqueAlbums.values) {
      _albumCache[album.id] = album;
      final clean = album.id.replaceAll('jiosaavn_', '');
      _albumCache[clean] = album;
    }

    return uniqueAlbums.values.toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    final cacheKey = query.trim().toLowerCase();
    if (_artistSearchCache.containsKey(cacheKey)) {
      return _artistSearchCache[cacheKey]!;
    }

    final Map<String, Artist> uniqueArtists = {};

    // 1. Check known verified artist portraits first
    kKnownArtistImages.forEach((artistKey, portraitUrl) {
      final canonicalName = kArtistCanonicalNames[artistKey] ?? artistKey;
      final cleanKey = getCleanArtistKey(cacheKey);
      if (artistKey.contains(cleanKey) || cleanKey.contains(artistKey) || canonicalName.toLowerCase().contains(cacheKey)) {
        uniqueArtists[artistKey] = Artist(
          id: 'artist_$artistKey',
          name: canonicalName,
          artworkUrl: portraitUrl,
          subscribers: 'Verified Artist',
          isVerified: true,
        );
      }
    });

    // 2. Query direct JioSaavn artist search endpoint
    try {
      final jioSaavn = getIt<JioSaavnService>();
      final jioArtists = await jioSaavn.searchArtists(query).timeout(const Duration(seconds: 5), onTimeout: () => []);
      for (final a in jioArtists) {
        final rawName = a['name'] as String? ?? a['title'] as String? ?? '';
        final cleanKey = getCleanArtistKey(rawName);
        if (cleanKey.isEmpty) continue;

        final canonicalName = getCleanArtistName(rawName);
        final imagesRaw = a['image'] as List<dynamic>? ?? [];
        String img = '';
        if (imagesRaw.isNotEmpty) {
          final last = imagesRaw.last;
          if (last is Map) {
            img = last['url']?.toString() ?? last['link']?.toString() ?? '';
          }
        }
        if (img.isEmpty && a['artworkUrl'] != null) {
          img = a['artworkUrl'].toString();
        }
        // Normalize low-res images to HD 500x500 CDN portraits
        img = img.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
        img = getArtistPortrait(rawName, img);

        final id = a['id']?.toString() ?? cleanKey;
        if (!uniqueArtists.containsKey(cleanKey) && img.isNotEmpty) {
          uniqueArtists[cleanKey] = Artist(
            id: 'artist_$id',
            name: canonicalName,
            artworkUrl: img,
            subscribers: 'Verified Artist',
            isVerified: true,
          );
        }
      }
    } catch (_) {}

    // 3. Extract all artists/singers/composers from songs matching the search query
    try {
      final matchingSongs = await searchSongs(query);
      for (final song in matchingSongs) {
        final rawArtists = song.artist
            .replaceAll('feat.', ',')
            .replaceAll('ft.', ',')
            .replaceAll('&', ',')
            .replaceAll('•', ',')
            .split(',');

        for (final raw in rawArtists) {
          final trimmed = raw.trim();
          if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown artist') continue;

          final cleanKey = getCleanArtistKey(trimmed);
          if (cleanKey.isEmpty || uniqueArtists.containsKey(cleanKey)) continue;

          final canonicalName = getCleanArtistName(trimmed);
          final portrait = getArtistPortrait(trimmed, song.artworkUrl);

          uniqueArtists[cleanKey] = Artist(
            id: 'artist_${song.id}_$cleanKey',
            name: canonicalName,
            artworkUrl: portrait,
            subscribers: 'Artist',
            isVerified: true,
          );
        }
        if (uniqueArtists.length >= 30) break;
      }
    } catch (_) {}

    final result = uniqueArtists.values.toList();
    if (result.isNotEmpty) {
      _artistSearchCache[cacheKey] = result;
    }
    return result;
  }

  final Map<String, HomeData> _homeFeedMemoryCache = {};

  static String _canonicalTrackKey(Song s) {
    var cleanTitle = s.title.toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    if (cleanTitle.isEmpty) cleanTitle = s.id.toLowerCase();

    final cleanArtist = s.artist.toLowerCase()
        .split(',').first
        .split('&').first
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    return '$cleanTitle|$cleanArtist';
  }

  static Map<String, dynamic> _songToJson(Song s) => {
    'id': s.id,
    'title': s.title,
    'artist': s.artist,
    'album': s.album,
    'durationMs': s.duration.inMilliseconds,
    'artworkUrl': s.artworkUrl,
    'streamUrl': s.streamUrl,
    'videoId': s.videoId,
    'source': s.source,
  };

  static Song _songFromJson(Map<String, dynamic> j) => Song(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    artist: j['artist'] as String? ?? '',
    album: j['album'] as String? ?? '',
    duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
    artworkUrl: j['artworkUrl'] as String? ?? '',
    streamUrl: j['streamUrl'] as String?,
    videoId: j['videoId'] as String? ?? '',
    source: j['source'] as String? ?? 'JioSaavn',
  );

  static Map<String, dynamic> _albumToJson(Album a) => {
    'id': a.id,
    'title': a.title,
    'artist': a.artist,
    'artworkUrl': a.artworkUrl,
    'year': a.year,
    'tracks': a.tracks.map(_songToJson).toList(),
    'songCount': a.songCount,
    'source': a.source,
  };

  static Album _albumFromJson(Map<String, dynamic> j) => Album(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    artist: j['artist'] as String? ?? '',
    artworkUrl: j['artworkUrl'] as String? ?? '',
    year: j['year'] as int?,
    tracks: ((j['tracks'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    songCount: (j['songCount'] as num?)?.toInt() ?? 0,
    source: j['source'] as String? ?? 'JioSaavn',
  );

  static Map<String, dynamic> _artistToJson(Artist a) => {
    'id': a.id,
    'name': a.name,
    'artworkUrl': a.artworkUrl,
    'subscribers': a.subscribers,
    'isVerified': a.isVerified,
  };

  static Artist _artistFromJson(Map<String, dynamic> j) => Artist(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    artworkUrl: j['artworkUrl'] as String? ?? '',
    subscribers: j['subscribers'] as String? ?? '',
    isVerified: j['isVerified'] as bool? ?? false,
  );

  static Map<String, dynamic> _moodToJson(MoodCategory m) => {
    'id': m.id,
    'title': m.title,
  };

  static MoodCategory _moodFromJson(Map<String, dynamic> j) => MoodCategory(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
  );

  static Map<String, dynamic> _homeDataToJson(HomeData d) => {
    'quickPicks': d.quickPicks.map(_songToJson).toList(),
    'newReleases': d.newReleases.map(_albumToJson).toList(),
    'charts': d.charts.map(_songToJson).toList(),
    'moods': d.moods.map(_moodToJson).toList(),
    'listenAgain': d.listenAgain.map(_songToJson).toList(),
    'recommendedArtists': d.recommendedArtists.map(_artistToJson).toList(),
    'featuredPlaylist': d.featuredPlaylist != null ? _albumToJson(d.featuredPlaylist!) : null,
    'trendingSongs': d.trendingSongs.map(_songToJson).toList(),
    'featuredPlaylistsForYou': d.featuredPlaylistsForYou.map(_albumToJson).toList(),
    'indianMusic': d.indianMusic.map(_songToJson).toList(),
    'forgottenFavorites': d.forgottenFavorites.map(_songToJson).toList(),
    'albumsForYou': d.albumsForYou.map(_albumToJson).toList(),
    'soundCloudLounge': d.soundCloudLounge.map(_songToJson).toList(),
    'spotifyTopHits': d.spotifyTopHits.map(_songToJson).toList(),
    'top100India': d.top100India.map(_songToJson).toList(),
    'top100International': d.top100International.map(_songToJson).toList(),
    'internationalHits': d.internationalHits.map(_songToJson).toList(),
    'punjabiHits': d.punjabiHits.map(_songToJson).toList(),
    'romanticMelodies': d.romanticMelodies.map(_songToJson).toList(),
    'partyDanceMix': d.partyDanceMix.map(_songToJson).toList(),
    'hindiHits': d.hindiHits.map(_songToJson).toList(),
    'sufiGhazals': d.sufiGhazals.map(_songToJson).toList(),
    'devotionalBhakti': d.devotionalBhakti.map(_songToJson).toList(),
    'retro90s': d.retro90s.map(_songToJson).toList(),
    'bhangraDhol': d.bhangraDhol.map(_songToJson).toList(),
    'indieHindi': d.indieHindi.map(_songToJson).toList(),
    'spotifyIndiaTop50': d.spotifyIndiaTop50.map(_songToJson).toList(),
    'newMusicFridayIndia': d.newMusicFridayIndia.map(_songToJson).toList(),
  };

  static HomeData _homeDataFromJson(Map<String, dynamic> j) => HomeData(
    quickPicks: ((j['quickPicks'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    newReleases: ((j['newReleases'] as List<dynamic>?) ?? []).map((t) => _albumFromJson(t as Map<String, dynamic>)).toList(),
    charts: ((j['charts'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    moods: ((j['moods'] as List<dynamic>?) ?? []).map((t) => _moodFromJson(t as Map<String, dynamic>)).toList(),
    listenAgain: ((j['listenAgain'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    recommendedArtists: ((j['recommendedArtists'] as List<dynamic>?) ?? []).map((t) => _artistFromJson(t as Map<String, dynamic>)).toList(),
    featuredPlaylist: j['featuredPlaylist'] != null ? _albumFromJson(j['featuredPlaylist'] as Map<String, dynamic>) : null,
    trendingSongs: ((j['trendingSongs'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    featuredPlaylistsForYou: ((j['featuredPlaylistsForYou'] as List<dynamic>?) ?? []).map((t) => _albumFromJson(t as Map<String, dynamic>)).toList(),
    indianMusic: ((j['indianMusic'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    forgottenFavorites: ((j['forgottenFavorites'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    albumsForYou: ((j['albumsForYou'] as List<dynamic>?) ?? []).map((t) => _albumFromJson(t as Map<String, dynamic>)).toList(),
    soundCloudLounge: ((j['soundCloudLounge'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    spotifyTopHits: ((j['spotifyTopHits'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    top100India: ((j['top100India'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    top100International: ((j['top100International'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    internationalHits: ((j['internationalHits'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    punjabiHits: ((j['punjabiHits'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    romanticMelodies: ((j['romanticMelodies'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    partyDanceMix: ((j['partyDanceMix'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    hindiHits: ((j['hindiHits'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    sufiGhazals: ((j['sufiGhazals'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    devotionalBhakti: ((j['devotionalBhakti'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    retro90s: ((j['retro90s'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    bhangraDhol: ((j['bhangraDhol'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    indieHindi: ((j['indieHindi'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    spotifyIndiaTop50: ((j['spotifyIndiaTop50'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
    newMusicFridayIndia: ((j['newMusicFridayIndia'] as List<dynamic>?) ?? []).map((t) => _songFromJson(t as Map<String, dynamic>)).toList(),
  );

  @override
  Future<HomeData> getHomeFeed({String? language}) async {
    final now = DateTime.now();
    final todayStr = '${now.year}_${now.month}_${now.day}';
    final langKey = language ?? 'All';
    final cacheKey = '${langKey}_$todayStr';

    if (_homeFeedMemoryCache.containsKey(cacheKey)) {
      return _homeFeedMemoryCache[cacheKey]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clean up previous days' home feed cache entries to avoid storage bloat
      final oldKeys = prefs.getKeys().where((k) => k.startsWith('home_feed_cache_') && !k.endsWith(todayStr)).toList();
      for (final k in oldKeys) {
        await prefs.remove(k);
      }

      final cachedStr = prefs.getString('home_feed_cache_$cacheKey');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr) as Map<String, dynamic>;
        final cachedData = _homeDataFromJson(decoded);

        // If stale cache has junk/empty albums, invalidate and fetch fresh
        final hasJunkAlbums = cachedData.albumsForYou.any((a) => a.tracks.isEmpty || a.title.toLowerCase().contains('trailer') || a.title.toLowerCase().contains('sample') || a.title.toLowerCase().contains('testing')) ||
            cachedData.newReleases.any((a) => a.tracks.isEmpty || a.title.toLowerCase().contains('trailer') || a.title.toLowerCase().contains('sample'));

        if (!hasJunkAlbums) {
          _homeFeedMemoryCache[cacheKey] = cachedData;
          for (final a in [...cachedData.newReleases, ...cachedData.albumsForYou, ...cachedData.featuredPlaylistsForYou]) {
            if (a.tracks.isNotEmpty) {
              _albumCache[a.id] = a;
              _albumCache[a.title.toLowerCase()] = a;
            }
          }
          // Background refresh to keep data updated
          unawaited(_fetchFreshHomeFeed(cacheKey: cacheKey, language: language));
          return cachedData;
        }
      }
    } catch (_) {}

    return _fetchFreshHomeFeed(cacheKey: cacheKey, language: language);
  }

  Future<HomeData> _fetchFreshHomeFeed({required String cacheKey, String? language}) async {
    final jioSaavn = getIt<JioSaavnService>();
    final soundCloud = getIt<SoundCloudService>();
    final spotify = getIt<SpotifyService>();
    final langSuffix = (language != null && language.isNotEmpty && language != 'All') ? ' $language' : '';

    // ── Daily rotation index ──────────────────────────────────────────────────
    // Advances 1 step per day so every section gets fresh queries each new day.
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;

    String pick(List<String> pool) => pool[dayOfYear % pool.length];

    // ── Helper fetch methods ──────────────────────────────────────────────────
    Future<List<Song>> fetchJio(String q, {int limit = 30}) async {
      try {
        final tracks = await jioSaavn.search(q, limit: limit).timeout(const Duration(seconds: 12), onTimeout: () => []);
        return tracks.map((t) => Song(
          id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
          title: t.title,
          artist: t.artist,
          album: t.album,
          duration: t.duration,
          artworkUrl: t.artworkUrl,
          videoId: t.id,
          source: 'JioSaavn',
        )).toList();
      } catch (_) {
        return [];
      }
    }

    Future<List<Song>> fetchSoundCloud(String q) async {
      try {
        final tracks = await soundCloud.search(q, limit: 25).timeout(const Duration(seconds: 4), onTimeout: () => []);
        return tracks.map((t) => Song(
          id: t.id,
          title: t.title,
          artist: t.artist,
          album: t.album,
          duration: t.duration,
          artworkUrl: t.artworkUrl,
          videoId: t.id,
          source: 'SoundCloud',
        )).toList();
      } catch (_) {
        return [];
      }
    }

    Future<List<Song>> fetchSpotifyPlaylist(String playlistId) async {
      try {
        final res = await spotify.fetchPlaylist(playlistId).timeout(const Duration(seconds: 6), onTimeout: () => null);
        if (res != null) {
          final tracks = (res['tracks'] as List<MusicTrack>?) ?? [];
          return tracks.map((t) => Song(
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artworkUrl: t.artworkUrl,
            videoId: t.id,
            source: 'Spotify',
          )).toList();
        }
      } catch (_) {}
      return [];
    }

    Future<List<Song>> fetchMultiJio(List<String> queries, {int limitEach = 30}) async {
      final responses = await Future.wait(queries.map((q) => fetchJio(q, limit: limitEach)));
      final Map<String, Song> unique = {};
      for (final r in responses) {
        for (final s in r) {
          if (!unique.containsKey(s.id)) unique[s.id] = s;
        }
      }
      return unique.values.toList();
    }

    List<Song> deduplicateSongs(List<Song> songs) {
      final seenIds = <String>{};
      final seenKeys = <String>{};
      final result = <Song>[];

      for (final s in songs) {
        final cleanId = s.id.startsWith('jiosaavn_') ? s.id.substring('jiosaavn_'.length) : s.id;
        final key = _canonicalTrackKey(s);

        if (!seenIds.contains(s.id) && !seenIds.contains(cleanId) && !seenKeys.contains(key)) {
          seenIds.add(s.id);
          seenIds.add(cleanId);
          seenKeys.add(key);
          result.add(s);
        }
      }
      return result;
    }

    bool isJunkAlbum(String title) {
      final l = title.toLowerCase();
      return l.contains('trailer') ||
          l.contains('teaser') ||
          l.contains('sample') ||
          l.contains('testing') ||
          l.contains('promo') ||
          l.contains('dialogue') ||
          l.contains('preview') ||
          l.contains('motion poster') ||
          l.contains('test track') ||
          l.length < 2;
    }

    Future<List<Album>> fetchCuratedAlbums(List<String> movieTitles) async {
      final List<Album> result = [];
      try {
        final albumFutures = movieTitles.map((title) async {
          final tracks = await fetchJio(title, limit: 10);
          final validTracks = deduplicateSongs(tracks.where((t) => !isJunkAlbum(t.title)).toList());
          if (validTracks.isNotEmpty) {
            final lead = validTracks.first;
            final album = Album(
              id: 'album_${lead.id}',
              title: lead.album.isNotEmpty && !isJunkAlbum(lead.album) ? lead.album : title,
              artist: lead.artist,
              artworkUrl: lead.artworkUrl,
              tracks: validTracks,
              songCount: validTracks.length,
              source: lead.source,
            );
            _albumCache[album.id] = album;
            _albumCache[album.title.toLowerCase()] = album;
            return album;
          }
          return null;
        });
        final fetched = await Future.wait(albumFutures);
        for (final a in fetched) {
          if (a != null) result.add(a);
        }
      } catch (_) {}
      return result;
    }

    // ── Rotating query pools (1 pool entry selected per day) ─────────────────
    // Each pool has 5 entries → completes one full rotation every 5 days.

    final quickPicksQuery = pick([
      'trending top hits bollywood$langSuffix',
      'superhit hindi songs popular$langSuffix',
      'top 40 bollywood songs week$langSuffix',
      'chartbuster hits india$langSuffix',
      'latest popular songs 2024$langSuffix',
    ]);

    final trendingQuery = pick([
      'viral songs trending$langSuffix',
      'top trending indian songs this week$langSuffix',
      'viral bollywood hits 2024$langSuffix',
      'most played songs india today$langSuffix',
      'hit songs trending 2024$langSuffix',
    ]);

    final listenAgainQuery = pick([
      'romantic love songs hindi soulful',
      'arijit singh best romantic songs',
      'evergreen romantic bollywood classic',
      'best love songs hindi melody',
      'soulful duet songs hindi',
    ]);

    final chartsQuery = pick([
      'top 50 hindi weekly bollywood',
      'hindi chart top songs this week',
      'bollywood weekly chartbuster hits',
      'most popular hindi songs chart',
      'top hits hindi bollywood chart',
    ]);

    final indianMusicQuery = pick([
      'punjabi bollywood blockbuster hindi',
      'bollywood superhit indian music 2024',
      'top indian music mix all languages',
      'desi music hits india 2024',
      'indian chartbuster all genres',
    ]);

    final forgottenQuery = pick([
      'retro 90s classic evergreen bollywood hindi',
      'classic 2000s bollywood hits',
      'old hindi songs golden era',
      'evergreen classic songs kumar sanu alka yagnik',
      'retro bollywood udit narayan kavita krishnamurthy',
    ]);

    final soundCloudQuery = pick([
      'lofi hindi chill beats relaxing',
      'lofi bollywood remix slow chill',
      'hindi lofi chill remix songs',
      'ambient chill music hindi bollywood',
      'lofi acoustic hindi chill beats',
    ]);

    // ── Section result variables ──────────────────────────────────────────────
    List<Song> quickPicks = [];
    List<Album> newReleases = [];
    List<Song> charts = [];
    List<Song> listenAgain = [];
    List<Song> trendingSongs = [];
    List<Song> indianMusic = [];
    List<Song> forgottenFavorites = [];
    List<Album> albumsForYou = [];
    List<Album> featuredPlaylistsForYou = [];
    List<Song> soundCloudLounge = [];
    List<Song> spotifyTopHits = [];
    List<Song> top100India = [];
    List<Song> top100International = [];
    List<Song> internationalHits = [];
    List<Song> punjabiHits = [];
    List<Song> romanticMelodies = [];
    List<Song> partyDanceMix = [];
    List<Song> hindiHits = [];
    List<Song> sufiGhazals = [];
    List<Song> devotionalBhakti = [];
    List<Song> retro90s = [];
    List<Song> bhangraDhol = [];
    List<Song> indieHindi = [];
    List<Song> spotifyIndiaTop50 = [];
    List<Song> newMusicFridayIndia = [];

    final isEnglishSelected = language != null && language.toLowerCase().contains('english');

    // ── Fetch all sections in parallel ────────────────────────────────────────
    await Future.wait([
      fetchMultiJio([
        quickPicksQuery,
        'superhit bollywood songs trending 2024$langSuffix',
        'top hindi songs popular chart $langSuffix',
        'viral songs popular weekly $langSuffix',
      ], limitEach: 50).then((res) => quickPicks = res),
      fetchCuratedAlbums([
        'Stree 2', 'Fighter', 'Animal', 'Dunki', 'Jawan', 'Brahmastra', 'Pathaan',
        'Tu Jhoothi Main Makkaar', 'Gadar 2', 'Rocky Aur Rani Kii Prem Kahaani',
      ]).then((res) => newReleases = res),
      fetchMultiJio([
        chartsQuery,
        'top 50 hindi weekly bollywood',
        'official bollywood chartbusters 2024',
        'most played hindi songs chart week',
      ], limitEach: 50).then((res) => charts = res),
      fetchMultiJio([
        listenAgainQuery,
        'arijit singh best romantic songs hindi',
        'soulful hindi love songs emotional',
        'romantic melodies evergreen hits',
      ], limitEach: 50).then((res) => listenAgain = res),
      fetchMultiJio([
        trendingQuery,
        'top trending indian songs this week',
        'viral bollywood hits 2024',
        'most played songs india today trending',
      ], limitEach: 50).then((res) => trendingSongs = res),
      fetchMultiJio([
        indianMusicQuery,
        'punjabi bollywood blockbuster hindi 2024',
        'all india music superhits hindi',
        'crossover indian superhits music',
      ], limitEach: 50).then((res) => indianMusic = res),
      fetchMultiJio([
        forgottenQuery,
        'classic 2000s bollywood hits evergreen',
        'old hindi songs golden era nostalgic',
        'retro evergreen bollywood melodies',
      ], limitEach: 50).then((res) => forgottenFavorites = res),
      fetchCuratedAlbums([
        'Aashiqui 2', 'Kabir Singh', 'Rockstar', 'Yeh Jawaani Hai Deewani', 'Shershaah',
        'Ae Dil Hai Mushkil', 'Kalank', 'Luka Chuppi', 'Jab We Met', 'Dilwale',
      ]).then((res) => albumsForYou = res),
      fetchCuratedAlbums([
        'Badshah Party Hits', 'Honey Singh Hits', 'Punjabi Wedding Dhol',
        'Arijit Singh Romantic', 'Bollywood Dance Party', 'Hindi Lo-Fi Hits',
      ]).then((res) => featuredPlaylistsForYou = res),
      Future(() async {
        final scTracks = await fetchSoundCloud(soundCloudQuery);
        final jioTracks = await fetchMultiJio([
          'lofi chill remix beats hindi',
          'lofi bollywood chill beats slow',
          'relaxing chill study beats hindi',
        ], limitEach: 40);
        final combined = <String, Song>{};
        for (final s in scTracks) { combined[s.id] = s; }
        for (final s in jioTracks) { if (!combined.containsKey(s.id)) combined[s.id] = s; }
        soundCloudLounge = combined.values.toList();
      }),
      // Spotify: Top Hits (Hindi / Bollywood by default, English only if explicitly selected)
      fetchSpotifyPlaylist(isEnglishSelected
          ? pick([
              '37i9dQZF1DXcBWIGoYBM5M', // Today's Top Hits Global
              '37i9dQZEVXbMDoHDwVN2tF', // Top 50 - Global
              '37i9dQZF1DX4Wsb4d7NKWh', // All Out 2010s
            ])
          : pick([
              '37i9dQZF1DX0XUsuxWHRQd', // Bollywood Butter
              '37i9dQZF1DX0b1hHYQtJjp', // Hot Hits Hindi
              '37i9dQZEVXbMDoHDwVN2tF', // Top 50 - India Official Chart
            ])).then((res) => spotifyTopHits = res),
      // India Top 50 — PURE INDIAN CHARTS (Spotify India + JioSaavn Indian Top 50)
      Future(() async {
        final spotTracks = await fetchSpotifyPlaylist(pick([
          '37i9dQZEVXbMDoHDwVN2tF', // Top 50 - India Official Chart
          '37i9dQZF1DX0XUsuxWHRQd', // Bollywood Butter
          '37i9dQZF1DX0b1hHYQtJjp', // Hot Hits Hindi
          '37i9dQZF1DX4JAvHpjipBk', // New Music Friday India
        ]));
        final jioIndia = await fetchMultiJio([
          'top 50 hindi songs week 2024',
          'bollywood top 50 songs india chart',
          'hindi trending top hits bollywood',
          'official india chart top songs',
        ], limitEach: 50);
        final combined = <String, Song>{};
        for (final s in spotTracks) {
          combined[s.id] = s;
        }
        for (final s in jioIndia) {
          if (!combined.containsKey(s.id)) combined[s.id] = s;
        }
        spotifyIndiaTop50 = combined.values.toList();
      }),
      // New Music Friday India (Spotify + JioSaavn Indian new releases)
      Future(() async {
        final spotTracks = await fetchSpotifyPlaylist('37i9dQZF1DX4JAvHpjipBk');
        final jioNew = await fetchMultiJio([
          'latest hindi songs 2024 new release',
          'new bollywood songs this week 2024',
          'fresh hindi music releases 2024',
        ], limitEach: 40);
        final combined = <String, Song>{};
        for (final s in spotTracks) {
          combined[s.id] = s;
        }
        for (final s in jioNew) {
          if (!combined.containsKey(s.id)) combined[s.id] = s;
        }
        newMusicFridayIndia = combined.values.toList();
      }),
      // Hindi Hits — always Hindi/Bollywood, 6 diverse queries with 50 tracks each for 100+ songs
      fetchMultiJio([
        pick([
          'bollywood superhit songs 2024 hindi',
          'top bollywood songs this week hindi',
          'most played bollywood hindi 2024',
          'popular hindi film songs 2024',
          'bollywood hits chart 2024',
        ]),
        pick([
          'arijit singh shreya ghoshal soulful hindi',
          'jubin nautiyal armaan malik new songs',
          'neha kakkar tony kakkar latest 2024',
          'atif aslam hindi songs popular',
          'shreya ghoshal best romantic songs',
        ]),
        'hindi chartbuster top songs trending bollywood',
        'new hindi songs latest hits 2024',
        'top 50 hindi weekly blockbuster hits',
        'latest bollywood chartbusters popular',
      ], limitEach: 50).then((res) => hindiHits = res),
      // Top 100 Blockbusters (Hindi by default)
      fetchMultiJio(isEnglishSelected
          ? [
              'billboard hot 100 global top hits english',
              'today top hits global english songs',
              'top western billboard songs 2024',
            ]
          : [
              'bollywood blockbuster top 100 songs',
              'superhit hindi songs all time top 100',
              'hindi chartbuster top 100 hits bollywood',
              'all time top 100 hindi blockbuster hits',
            ], limitEach: 50).then((res) => top100International = res),
      // Punjabi Hits & Bangers — 5 parallel queries + Spotify Punjabi 101
      Future(() async {
        final jioTracks = await fetchMultiJio([
          pick([
            'latest punjabi party hits banger 2024',
            'punjabi top 50 songs trending',
            'punjabi viral hits 2024 popular',
            'new punjabi songs chartbusters',
          ]),
          'diljit dosanjh sidhu moosewala ap dhillon superhit',
          'karan aujla shubh guru randhawa hits 2024',
          'punjabi blockbuster dance party banger',
          'punjabi superhit songs all time hits',
        ], limitEach: 50);
        final spotTracks = await fetchSpotifyPlaylist(pick([
          '37i9dQZF1DX4sWSpwq3LiO', // Punjabi 101
          '37i9dQZF1DX5cZuAhlRIUV', // Punjabi Pop
        ]));
        final combined = <String, Song>{};
        for (final s in jioTracks) {
          combined[s.id] = s;
        }
        for (final s in spotTracks) {
          if (!combined.containsKey(s.id)) combined[s.id] = s;
        }
        punjabiHits = combined.values.toList();
      }),
      // Romantic Melodies — 5 parallel queries + Spotify Romantic Hindi
      Future(() async {
        final jioTracks = await fetchMultiJio([
          pick([
            'romantic melodies soulful love arijit shreya hindi',
            'best hindi love songs romantic 2024',
            'soulful romantic duet hindi songs',
            'most romantic bollywood songs 2024',
            'love songs hindi melody emotional',
          ]),
          'arijit singh romantic love songs hindi',
          'shreya ghoshal atif aslam soulful duet hindi',
          'armaan malik jubin nautiyal romantic hits',
          'bollywood love songs emotional melody 2024',
          'evergreen romantic love songs hindi',
        ], limitEach: 50);
        final spotTracks = await fetchSpotifyPlaylist('37i9dQZF1DWU4xkXueiKGa'); // Romantic Bollywood
        final combined = <String, Song>{};
        for (final s in jioTracks) {
          combined[s.id] = s;
        }
        for (final s in spotTracks) {
          if (!combined.containsKey(s.id)) combined[s.id] = s;
        }
        romanticMelodies = combined.values.toList();
      }),
      // Party & Dance Mix — 5 parallel queries
      fetchMultiJio([
        pick([
          'bollywood dance party club edm mix hindi',
          'bollywood party hits 2024 dance',
          'dance club mix hindi bollywood',
          'party songs bollywood 2024 banger',
          'best dance songs hindi 2024',
        ]),
        'badshah neha kakkar honey singh party songs',
        'bollywood club banger dj remix 2024',
        'top hindi dance party blockbuster hits',
        'high energy bollywood dance club songs',
      ], limitEach: 50).then((res) => partyDanceMix = res),
      // Sufi & Ghazals 🕉 — 5 parallel queries
      fetchMultiJio([
        pick([
          'sufi songs qawwali nusrat fateh ali khan',
          'sufi bollywood songs spiritual',
          'ghazal jagjit singh mehdi hassan',
          'sufi hits rahat fateh ali popular',
          'spiritual sufi qawwali songs india',
        ]),
        'rahat fateh ali khan sufi qawwali hits',
        'jagjit singh ghazals evergreen classic',
        'mehdi hassan ghulam ali best ghazals',
        'spiritual sufi bollywood songs soulful',
      ], limitEach: 50).then((res) => sufiGhazals = res),
      // Devotional & Bhakti 🙏 — 5 parallel queries
      fetchMultiJio([
        pick([
          'bhajan aarti devotional songs hindi',
          'ganesh bhajan krishna aarti devotional',
          'morning bhajan devotional popular',
          'hanuman chalisa bhajan popular',
          'bhakti songs hindi popular 2024',
        ]),
        'anuradha paudwal gulshan kumar best bhajans',
        'hanuman chalisa shiv aarti krishna bhajan',
        'morning bhakti songs hindi devotional',
        'spiritual chants gayatri mantra aarti',
      ], limitEach: 50).then((res) => devotionalBhakti = res),
      // 90s Retro Throwback 🎤 — 5 parallel queries
      fetchMultiJio([
        pick([
          'retro 90s classic evergreen bollywood hindi',
          'old hindi songs 90s classic hits',
          'kumar sanu alka yagnik 90s songs',
          'evergreen 90s hindi film songs',
          'udit narayan kavita krishnamurthy classic',
        ]),
        'kumar sanu alka yagnik 90s romantic hits',
        'udit narayan kavita krishnamurthy evergreen',
        'sonu nigam 90s superhit bollywood songs',
        'golden 90s hindi songs classic blockbusters',
      ], limitEach: 50).then((res) => retro90s = res),
      // Bhangra & Dhol 🥁 — 5 parallel energetic dhol/wedding queries
      fetchMultiJio([
        pick([
          'bhangra party hits punjabi dhol',
          'bhangra dance songs popular 2024',
          'punjabi bhangra wedding songs',
          'desi bhangra hits punjabi 2024',
          'bhangra dhol mix party songs',
        ]),
        'punjabi dhol mix party beats dance',
        'desi dhol bhangra wedding hits 2024',
        'superhit bhangra songs dhol beats',
        'dhol dhamaka punjabi bhangra banger',
      ], limitEach: 50).then((res) => bhangraDhol = res),
      // Indie Hindi 🎧 (SoundCloud + JioSaavn Indie)
      Future(() async {
        final scTracks = await fetchSoundCloud(pick([
          'indie hindi songs 2024',
          'hindi indie alternative songs',
          'independent hindi music artists',
          'indie bollywood chill songs',
          'desi indie music hindi songs',
        ]));
        final jioTracks = await fetchMultiJio([
          'indie hindi songs independent artists 2024',
          'prateek kuhad anuv jain jasleen royal indie',
          'acoustic indie hindi songs chill',
        ], limitEach: 40);
        final combined = <String, Song>{};
        for (final s in scTracks) { combined[s.id] = s; }
        for (final s in jioTracks) { if (!combined.containsKey(s.id)) combined[s.id] = s; }
        indieHindi = combined.values.toList();
      }),
    ]);

    // ── Helper backfill function to guarantee at least minCount unique songs per section ──
    List<Song> ensureCount(List<Song> target, List<Song> donorPool, {int minCount = 100}) {
      final deduped = deduplicateSongs(target);
      if (deduped.length >= minCount) return deduped;

      final seenKeys = <String>{for (final s in deduped) _canonicalTrackKey(s)};
      final seenIds = <String>{for (final s in deduped) s.id};
      final result = List<Song>.from(deduped);

      for (final s in deduplicateSongs(donorPool)) {
        final key = _canonicalTrackKey(s);
        final cleanId = s.id.startsWith('jiosaavn_') ? s.id.substring('jiosaavn_'.length) : s.id;
        if (!seenKeys.contains(key) && !seenIds.contains(s.id) && !seenIds.contains(cleanId)) {
          seenKeys.add(key);
          seenIds.add(s.id);
          seenIds.add(cleanId);
          result.add(s);
        }
        if (result.length >= minCount) break;
      }
      return result;
    }

    // ── Guarantee 100+ unique non-repeated songs across all genre sections ────
    hindiHits = ensureCount(hindiHits, [...charts, ...indianMusic, ...quickPicks, ...trendingSongs, ...retro90s, ...sufiGhazals, ...romanticMelodies, ...partyDanceMix], minCount: 100);
    romanticMelodies = ensureCount(romanticMelodies, [...hindiHits, ...listenAgain, ...sufiGhazals, ...charts, ...retro90s, ...quickPicks], minCount: 100);
    partyDanceMix = ensureCount(partyDanceMix, [...bhangraDhol, ...punjabiHits, ...trendingSongs, ...hindiHits, ...quickPicks], minCount: 100);
    punjabiHits = ensureCount(punjabiHits, [...bhangraDhol, ...partyDanceMix, ...indianMusic, ...trendingSongs], minCount: 100);
    bhangraDhol = ensureCount(bhangraDhol, [...punjabiHits, ...partyDanceMix, ...indianMusic], minCount: 100);
    sufiGhazals = ensureCount(sufiGhazals, [...romanticMelodies, ...retro90s, ...listenAgain, ...hindiHits], minCount: 100);
    devotionalBhakti = ensureCount(devotionalBhakti, [...sufiGhazals, ...retro90s, ...forgottenFavorites], minCount: 100);
    retro90s = ensureCount(retro90s, [...forgottenFavorites, ...sufiGhazals, ...romanticMelodies, ...hindiHits], minCount: 100);
    quickPicks = ensureCount(quickPicks, [...trendingSongs, ...hindiHits, ...charts, ...indianMusic], minCount: 100);
    trendingSongs = ensureCount(trendingSongs, [...quickPicks, ...hindiHits, ...charts, ...partyDanceMix], minCount: 100);
    charts = ensureCount(charts, [...hindiHits, ...trendingSongs, ...quickPicks, ...indianMusic], minCount: 100);
    indianMusic = ensureCount(indianMusic, [...punjabiHits, ...bhangraDhol, ...hindiHits, ...trendingSongs], minCount: 100);
    forgottenFavorites = ensureCount(forgottenFavorites, [...retro90s, ...sufiGhazals, ...romanticMelodies, ...hindiHits], minCount: 100);
    indieHindi = ensureCount(indieHindi, [...soundCloudLounge, ...romanticMelodies, ...quickPicks], minCount: 100);
    soundCloudLounge = ensureCount(soundCloudLounge, [...indieHindi, ...forgottenFavorites, ...quickPicks], minCount: 100);
    spotifyIndiaTop50 = ensureCount(spotifyIndiaTop50, [...hindiHits, ...charts, ...indianMusic, ...quickPicks], minCount: 100);
    newMusicFridayIndia = ensureCount(newMusicFridayIndia, [...hindiHits, ...trendingSongs, ...quickPicks], minCount: 100);
    top100International = ensureCount(top100International, [...spotifyTopHits, ...quickPicks], minCount: 100);
    listenAgain = ensureCount(listenAgain, [...romanticMelodies, ...quickPicks, ...hindiHits], minCount: 100);
    top100India = spotifyIndiaTop50;
    internationalHits = top100International;

    List<Album> createAlbumsFromSongs(List<Song> songs) {
      final Map<String, List<Song>> byAlbum = {};
      for (final s in deduplicateSongs(songs)) {
        final albumName = s.album.isNotEmpty && !isJunkAlbum(s.album)
            ? s.album
            : (s.title.isNotEmpty && !isJunkAlbum(s.title) ? s.title : '');
        if (albumName.isNotEmpty && !isJunkAlbum(s.title)) {
          byAlbum.putIfAbsent(albumName, () => []).add(s);
        }
      }
      final result = <Album>[];
      for (final entry in byAlbum.entries) {
        final albumTracks = entry.value;
        if (albumTracks.isNotEmpty) {
          final lead = albumTracks.first;
          final album = Album(
            id: 'album_${lead.id}',
            title: entry.key,
            artist: lead.artist,
            artworkUrl: lead.artworkUrl,
            tracks: albumTracks,
            songCount: albumTracks.length,
            source: lead.source,
          );
          _albumCache[album.id] = album;
          _albumCache[album.title.toLowerCase()] = album;
          result.add(album);
        }
      }
      return result.take(15).toList();
    }

    if (newReleases.isEmpty) {
      newReleases = createAlbumsFromSongs([...trendingSongs, ...quickPicks, ...hindiHits]);
    }
    if (albumsForYou.isEmpty) {
      albumsForYou = createAlbumsFromSongs([...romanticMelodies, ...punjabiHits, ...indianMusic]);
    }
    if (featuredPlaylistsForYou.isEmpty) {
      featuredPlaylistsForYou = createAlbumsFromSongs([...partyDanceMix, ...sufiGhazals, ...retro90s]);
    }

    final List<Artist> recommendedArtists = [];
    final Set<String> seenArtistKeys = {};

    // 1. Add top artists with verified JioSaavn CDN portraits
    kKnownArtistImages.forEach((artistKey, portraitUrl) {
      if (!seenArtistKeys.contains(artistKey)) {
        seenArtistKeys.add(artistKey);
        final canonicalName = kArtistCanonicalNames[artistKey] ?? artistKey;
        recommendedArtists.add(Artist(
          id: 'artist_$artistKey',
          name: canonicalName,
          artworkUrl: portraitUrl,
          subscribers: 'Verified Artist',
          isVerified: true,
        ));
      }
    });

    // 2. Add any additional dynamic artists from current tracks
    for (final s in [...quickPicks, ...trendingSongs, ...top100India, ...internationalHits, ...spotifyTopHits]) {
      final rawArtist = s.artist.split(',').first.split('&').first.split('•').first.trim();
      final key = getCleanArtistKey(rawArtist);
      if (key.isNotEmpty && !seenArtistKeys.contains(key)) {
        seenArtistKeys.add(key);
        recommendedArtists.add(Artist(
          id: 'artist_${s.id}',
          name: rawArtist,
          artworkUrl: s.artworkUrl,
          subscribers: 'Artist',
          isVerified: false,
        ));
      }
    }

    final homeData = HomeData(
      quickPicks: quickPicks,
      newReleases: newReleases,
      charts: charts,
      moods: const [
        MoodCategory(id: 'trending', title: 'Trending'),
        MoodCategory(id: 'romance', title: 'Romance'),
        MoodCategory(id: 'party', title: 'Party'),
        MoodCategory(id: 'punjabi', title: 'Punjabi'),
        MoodCategory(id: 'chill', title: 'Chill & Lo-Fi'),
        MoodCategory(id: 'workout', title: 'Workout & Gym'),
        MoodCategory(id: 'retro', title: 'Retro Classics'),
        MoodCategory(id: 'edm', title: 'EDM & Dance'),
        MoodCategory(id: 'acoustic', title: 'Acoustic & Unplugged'),
        MoodCategory(id: 'hiphop', title: 'Hip Hop & Rap'),
        MoodCategory(id: 'bollywood', title: 'Bollywood Beats'),
        MoodCategory(id: 'devotional', title: 'Devotional & Bhakti'),
        MoodCategory(id: 'focus', title: 'Focus & Study'),
        MoodCategory(id: 'rock', title: 'Rock & Metal'),
        MoodCategory(id: 'sufi', title: 'Sufi & Ghazals'),
        MoodCategory(id: 'kpop', title: 'K-Pop & J-Pop'),
      ],
      listenAgain: listenAgain,
      recommendedArtists: recommendedArtists,
      featuredPlaylist: featuredPlaylistsForYou.isNotEmpty ? featuredPlaylistsForYou.first : null,
      trendingSongs: trendingSongs,
      featuredPlaylistsForYou: featuredPlaylistsForYou,
      indianMusic: indianMusic,
      forgottenFavorites: forgottenFavorites,
      albumsForYou: albumsForYou,
      soundCloudLounge: soundCloudLounge,
      spotifyTopHits: spotifyTopHits,
      top100India: top100India,
      top100International: top100International,
      internationalHits: internationalHits,
      punjabiHits: punjabiHits,
      romanticMelodies: romanticMelodies,
      partyDanceMix: partyDanceMix,
      hindiHits: hindiHits,
      sufiGhazals: sufiGhazals,
      devotionalBhakti: devotionalBhakti,
      retro90s: retro90s,
      bhangraDhol: bhangraDhol,
      indieHindi: indieHindi,
      spotifyIndiaTop50: spotifyIndiaTop50,
      newMusicFridayIndia: newMusicFridayIndia,
    );

    // Save to memory cache and persist to SharedPreferences for fast offline/cold start
    _homeFeedMemoryCache[cacheKey] = homeData;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('home_feed_cache_$cacheKey', jsonEncode(_homeDataToJson(homeData)));
    } catch (_) {}

    return homeData;
  }

  @override
  Future<Album> getAlbumDetails(String albumId, {String? fallbackTitle}) async {
    final cleanId = albumId.startsWith('jiosaavn_') ? albumId.substring('jiosaavn_'.length) : albumId;
    final cachedAlbum = _albumCache[albumId] ?? _albumCache[cleanId] ?? (fallbackTitle != null ? _albumCache[fallbackTitle.toLowerCase()] : null);
    if (cachedAlbum != null && cachedAlbum.tracks.isNotEmpty) {
      return cachedAlbum;
    }

    bool isJunk(String title) {
      final l = title.toLowerCase();
      return l.contains('trailer') ||
          l.contains('teaser') ||
          l.contains('sample') ||
          l.contains('testing') ||
          l.contains('promo') ||
          l.contains('dialogue') ||
          l.contains('preview') ||
          l.length < 2;
    }

    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.browse(cleanId);
    final List<Song> decoratedTracks = tracks.where((t) => !isJunk(t.title)).map((t) => Song(
      id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artworkUrl: t.artworkUrl,
      videoId: t.id,
      source: 'JioSaavn',
    )).toList();

    // Safety net: if direct browse returned 0, search for songs belonging to this album
    if (decoratedTracks.isEmpty) {
      final searchKey = fallbackTitle?.trim().isNotEmpty == true
          ? fallbackTitle!.trim()
          : (cachedAlbum?.title.isNotEmpty == true ? cachedAlbum!.title : cleanId.replaceAll('album_', ''));

      try {
        final searchTracks = await jioSaavn.search(searchKey, limit: 50);
        final cleanKeyLower = searchKey.toLowerCase();
        
        final matched = searchTracks.where((t) {
          if (isJunk(t.title) || isJunk(t.album)) return false;
          final albLower = t.album.toLowerCase();
          final titleLower = t.title.toLowerCase();
          return albLower.contains(cleanKeyLower) ||
              titleLower.contains(cleanKeyLower) ||
              t.extras['album_id']?.toString() == cleanId;
        }).toList();

        final toAdd = matched.isNotEmpty ? matched : searchTracks.where((t) => !isJunk(t.title)).take(15).toList();
        final Set<String> seenIds = {};
        for (final t in toAdd) {
          final songId = t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}';
          if (!seenIds.contains(songId)) {
            seenIds.add(songId);
            decoratedTracks.add(Song(
              id: songId,
              title: t.title,
              artist: t.artist,
              album: t.album.isNotEmpty ? t.album : searchKey,
              duration: t.duration,
              artworkUrl: t.artworkUrl.isNotEmpty ? t.artworkUrl : (cachedAlbum?.artworkUrl ?? ''),
              videoId: t.id,
              source: 'JioSaavn',
            ));
          }
        }
      } catch (_) {}
    }

    final finalAlbum = Album(
      id: albumId,
      title: decoratedTracks.isNotEmpty
          ? decoratedTracks.first.album
          : (cachedAlbum?.title ?? fallbackTitle ?? 'Bollywood Album'),
      artist: decoratedTracks.isNotEmpty
          ? decoratedTracks.first.artist
          : (cachedAlbum?.artist ?? 'Various Artists'),
      artworkUrl: decoratedTracks.isNotEmpty
          ? decoratedTracks.first.artworkUrl
          : (cachedAlbum?.artworkUrl ?? ''),
      tracks: decoratedTracks,
      songCount: decoratedTracks.length,
      source: 'JioSaavn',
    );

    _albumCache[albumId] = finalAlbum;
    _albumCache[finalAlbum.title.toLowerCase()] = finalAlbum;
    return finalAlbum;
  }

  @override
  Future<Artist> getArtistDetails(String artistId) async {
    final cleanId = artistId.startsWith('artist_') ? artistId.substring('artist_'.length) : artistId;
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(cleanId, limit: 20);
    
    return Artist(
      id: artistId,
      name: cleanId,
      artworkUrl: tracks.isNotEmpty ? tracks.first.artworkUrl : '',
      subscribers: 'JioSaavn Artist',
      isVerified: true,
    );
  }

  @override
  Future<Playlist> getPlaylistDetails(String playlistId) async {
    final cleanId = playlistId.startsWith('jiosaavn_') ? playlistId.substring('jiosaavn_'.length) : playlistId;
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.browse(cleanId);
    final List<Song> decoratedTracks = tracks.map((t) => Song(
      id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artworkUrl: t.artworkUrl,
      videoId: t.id,
      source: 'JioSaavn',
    )).toList();

    return Playlist(
      id: playlistId,
      title: 'JioSaavn Playlist',
      description: 'Curated JioSaavn Music',
      artworkUrl: decoratedTracks.isNotEmpty ? decoratedTracks.first.artworkUrl : '',
      trackCount: decoratedTracks.length,
      songs: decoratedTracks,
      isYouTube: false,
      isLocal: false,
    );
  }

  @override
  Future<String> getStreamUrl(String videoId, {String quality = 'High'}) async {
    try {
      final resolver = getIt<UnifiedStreamResolver>();
      final result = await resolver.resolve(videoId: videoId, quality: quality);
      if (result != null && result.url.isNotEmpty) {
        return result.url;
      }
    } catch (_) {}

    throw StateError('Could not resolve stream URL for track: $videoId');
  }

  @override
  Future<String> getVideoStreamUrl(String videoId) async {
    throw UnsupportedError('Video playback is disabled');
  }

  @override
  Future<List<Song>> getRelatedSongs(String videoId) async {
    final jioSaavn = getIt<JioSaavnService>();
    final cleanId = videoId.startsWith('jiosaavn_') ? videoId.substring('jiosaavn_'.length) : videoId;
    final tracks = await jioSaavn.search(cleanId);
    if (tracks.isEmpty) return const [];
    final firstTrack = tracks.first;
    final related = await jioSaavn.search('${firstTrack.artist} songs');
    return related.map((t) => Song(
      id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artworkUrl: t.artworkUrl,
      videoId: t.id,
      source: 'JioSaavn',
    )).toList();
  }

  @override
  Future<ChartsData> getCharts({String? country}) async {
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search('trending top 50');
    final songs = tracks.map((t) => Song(
      id: t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}',
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artworkUrl: t.artworkUrl,
      videoId: t.id,
      source: 'JioSaavn',
    )).toList();

    return ChartsData(
      topSongs: songs,
      topArtists: const [],
      topAlbums: const [],
    );
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(query);
    return tracks.map((t) => t.title).toSet().toList();
  }
}
