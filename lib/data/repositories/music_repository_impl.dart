import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(query, limit: 50).timeout(const Duration(seconds: 4), onTimeout: () => []);
    final Map<String, Album> uniqueAlbums = {};
    for (final t in tracks) {
      final albumName = t.album.isNotEmpty ? t.album : 'Single';
      final albumId = t.id.startsWith('jiosaavn_') ? t.id : 'jiosaavn_${t.id}';
      if (!uniqueAlbums.containsKey(albumName)) {
        uniqueAlbums[albumName] = Album(
          id: albumId,
          title: albumName,
          artist: t.artist,
          artworkUrl: t.artworkUrl,
          tracks: [],
          songCount: 1,
          source: 'JioSaavn',
        );
      }
    }
    // Also include Spotify albums
    for (final t in tracks.take(15)) {
      final albumName = t.album.isNotEmpty ? t.album : 'Single';
      final spKey = 'sp_$albumName';
      if (!uniqueAlbums.containsKey(spKey)) {
        uniqueAlbums[spKey] = Album(
          id: 'spotify_${t.id.replaceAll('jiosaavn_', '')}',
          title: albumName,
          artist: t.artist,
          artworkUrl: t.artworkUrl,
          tracks: [],
          songCount: 1,
          source: 'Spotify',
        );
      }
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

    // Check known verified artist portraits first
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



    final result = uniqueArtists.values.toList();
    if (result.isNotEmpty) {
      _artistSearchCache[cacheKey] = result;
    }
    return result;
  }

  @override
  Future<HomeData> getHomeFeed({String? language}) async {
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

    Future<List<Album>> fetchJioAlbums(String q) async {
      try {
        final tracks = await jioSaavn.search(q, limit: 30).timeout(const Duration(seconds: 4), onTimeout: () => []);
        final Map<String, Album> unique = {};
        for (final t in tracks) {
          final albumName = t.album.isNotEmpty ? t.album : t.title;
          if (!unique.containsKey(albumName) && t.artworkUrl.isNotEmpty) {
            unique[albumName] = Album(
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
        return unique.values.toList();
      } catch (_) {
        return [];
      }
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

    final albumsQuery = pick([
      'superhit album songs$langSuffix',
      'bollywood album hits 2024$langSuffix',
      'top album releases india$langSuffix',
      'best album songs hindi$langSuffix',
      'popular album songs india$langSuffix',
    ]);

    final playlistsQuery = pick([
      'party dance mix playlists$langSuffix',
      'bollywood party playlist 2024$langSuffix',
      'top playlist songs india$langSuffix',
      'dance hits playlist hindi$langSuffix',
      'club mix playlist india$langSuffix',
    ]);

    final soundCloudQuery = pick([
      'lofi chill remix beats',
      'lofi hindi chill beats relaxing',
      'chill lo-fi study beats',
      'lofi bollywood remix slow',
      'ambient chill music hindi',
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

    // ── Fetch all sections in parallel ────────────────────────────────────────
    await Future.wait([
      fetchJio(quickPicksQuery).then((res) => quickPicks = res),
      fetchJioAlbums('latest releases 2024$langSuffix').then((res) => newReleases = res),
      fetchJio(chartsQuery).then((res) => charts = res),
      fetchJio(listenAgainQuery).then((res) => listenAgain = res),
      fetchJio(trendingQuery).then((res) => trendingSongs = res),
      fetchJio(indianMusicQuery).then((res) => indianMusic = res),
      fetchJio(forgottenQuery).then((res) => forgottenFavorites = res),
      fetchJioAlbums(albumsQuery).then((res) => albumsForYou = res),
      fetchJioAlbums(playlistsQuery).then((res) => featuredPlaylistsForYou = res),
      fetchSoundCloud(soundCloudQuery).then((res) => soundCloudLounge = res),
      // Spotify: Global Top Hits (rotates among 3 global playlists)
      fetchSpotifyPlaylist(pick([
        '37i9dQZF1DXcBWIGoYBM5M', // Today's Top Hits Global
        '37i9dQZEVXbMDoHDwVN2tF', // Top 50 - Global
        '37i9dQZF1DX4Wsb4d7NKWh', // All Out 2010s
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
        ], limitEach: 30);
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
        final jioNew = await fetchJio('latest hindi songs 2024 new release', limit: 40);
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
      // Top 100 India
      fetchMultiJio([
        pick([
          'hindi trending top hits bollywood',
          'bollywood chart top 2024 trending',
          'top 50 hindi songs popular week',
          'hindi chart hits this week',
          'bollywood trending songs today',
        ]),
        'bollywood blockbuster chartbusters hindi',
        'latest bollywood superhit songs hindi',
        'top 50 hindi weekly hits',
      ], limitEach: 30).then((res) => top100India = res),
      // Top 100 International
      fetchMultiJio([
        'billboard hot 100 global top hits english',
        pick([
          'international pop global viral hits english',
          'global top songs pop chart english',
          'world top hits english songs 2024',
          'viral pop hits english international',
          'global chart songs english 2024',
        ]),
        'today top hits global english songs',
      ], limitEach: 30).then((res) => top100International = res),
      // International Hits
      fetchJio(pick([
        'international pop global viral hits english',
        'top western songs trending 2024',
        'english pop hits global 2024',
        'popular english songs chart 2024',
        'viral english songs trending today',
      ]), limit: 35).then((res) => internationalHits = res),
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
      // Romantic Melodies
      fetchJio(pick([
        'romantic melodies soulful love arijit shreya hindi',
        'best hindi love songs romantic 2024',
        'soulful romantic duet hindi songs',
        'most romantic bollywood songs 2024',
        'love songs hindi melody emotional',
      ]), limit: 35).then((res) => romanticMelodies = res),
      // Party & Dance Mix
      fetchJio(pick([
        'bollywood dance party club edm mix hindi',
        'bollywood party hits 2024 dance',
        'dance club mix hindi bollywood',
        'party songs bollywood 2024 banger',
        'best dance songs hindi 2024',
      ]), limit: 35).then((res) => partyDanceMix = res),
      // Sufi & Ghazals 🕉
      fetchJio(pick([
        'sufi songs qawwali nusrat fateh ali khan',
        'sufi bollywood songs spiritual',
        'ghazal jagjit singh mehdi hassan',
        'sufi hits rahat fateh ali popular',
        'spiritual sufi qawwali songs india',
      ]), limit: 35).then((res) => sufiGhazals = res),
      // Devotional & Bhakti 🙏
      fetchJio(pick([
        'bhajan aarti devotional songs hindi',
        'ganesh bhajan krishna aarti devotional',
        'morning bhajan devotional popular',
        'hanuman chalisa bhajan popular',
        'bhakti songs hindi popular 2024',
      ]), limit: 30).then((res) => devotionalBhakti = res),
      // 90s Retro Throwback 🎤
      fetchJio(pick([
        'retro 90s classic evergreen bollywood hindi',
        'old hindi songs 90s classic hits',
        'kumar sanu alka yagnik 90s songs',
        'evergreen 90s hindi film songs',
        'udit narayan kavita krishnamurthy classic',
      ]), limit: 35).then((res) => retro90s = res),
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
      // Indie Hindi 🎧 (SoundCloud)
      fetchSoundCloud(pick([
        'indie hindi songs 2024',
        'hindi indie alternative songs',
        'independent hindi music artists',
        'indie bollywood chill songs',
        'desi indie music hindi songs',
      ])).then((res) => indieHindi = res),
    ]);

    // ── Guarantee 100+ songs in Hindi Hits & Top 100 India ──────────────────
    final hindiSet = <String, Song>{for (final s in hindiHits) s.id: s};
    for (final s in [...top100India, ...charts, ...indianMusic, ...quickPicks, ...trendingSongs, ...retro90s, ...sufiGhazals, ...romanticMelodies, ...partyDanceMix]) {
      if (!hindiSet.containsKey(s.id)) {
        hindiSet[s.id] = s;
      }
      if (hindiSet.length >= 100) break;
    }
    hindiHits = hindiSet.values.toList();

    final indiaSet = <String, Song>{for (final s in top100India) s.id: s};
    for (final s in [...hindiHits, ...trendingSongs, ...quickPicks, ...charts, ...indianMusic]) {
      if (!indiaSet.containsKey(s.id)) {
        indiaSet[s.id] = s;
      }
      if (indiaSet.length >= 100) break;
    }
    top100India = indiaSet.values.toList();

    if (top100International.isEmpty) top100International = [...spotifyTopHits, ...internationalHits];
    if (internationalHits.isEmpty) internationalHits = spotifyTopHits.isNotEmpty ? spotifyTopHits : quickPicks;
    final punjabiSet = <String, Song>{for (final s in punjabiHits) s.id: s};
    for (final s in [...bhangraDhol, ...indianMusic, ...partyDanceMix, ...trendingSongs]) {
      if (!punjabiSet.containsKey(s.id)) {
        punjabiSet[s.id] = s;
      }
      if (punjabiSet.length >= 80) break;
    }
    punjabiHits = punjabiSet.values.toList();

    final bhangraSet = <String, Song>{for (final s in bhangraDhol) s.id: s};
    for (final s in [...punjabiHits, ...indianMusic, ...partyDanceMix]) {
      if (!bhangraSet.containsKey(s.id)) {
        bhangraSet[s.id] = s;
      }
      if (bhangraSet.length >= 60) break;
    }
    bhangraDhol = bhangraSet.values.toList();

    if (romanticMelodies.isEmpty) romanticMelodies = listenAgain.isNotEmpty ? listenAgain : quickPicks;
    if (partyDanceMix.isEmpty) partyDanceMix = trendingSongs.isNotEmpty ? trendingSongs : quickPicks;
    if (soundCloudLounge.isEmpty) soundCloudLounge = forgottenFavorites.isNotEmpty ? forgottenFavorites : quickPicks;
    if (spotifyTopHits.isEmpty) spotifyTopHits = quickPicks;
    if (sufiGhazals.isEmpty) sufiGhazals = [...listenAgain.take(15), ...romanticMelodies.take(15)];
    if (devotionalBhakti.isEmpty) devotionalBhakti = [...forgottenFavorites.take(20)];
    if (retro90s.isEmpty) retro90s = forgottenFavorites.isNotEmpty ? forgottenFavorites : quickPicks;
    final indiaTop50Set = <String, Song>{for (final s in spotifyIndiaTop50) s.id: s};
    for (final s in [...top100India, ...hindiHits, ...charts, ...indianMusic]) {
      if (!indiaTop50Set.containsKey(s.id)) {
        indiaTop50Set[s.id] = s;
      }
      if (indiaTop50Set.length >= 50) break;
    }
    spotifyIndiaTop50 = indiaTop50Set.values.toList();

    final newMusicIndiaSet = <String, Song>{for (final s in newMusicFridayIndia) s.id: s};
    for (final s in [...hindiHits, ...top100India, ...trendingSongs]) {
      if (!newMusicIndiaSet.containsKey(s.id)) {
        newMusicIndiaSet[s.id] = s;
      }
      if (newMusicIndiaSet.length >= 50) break;
    }
    newMusicFridayIndia = newMusicIndiaSet.values.toList();

    if (albumsForYou.isEmpty && newReleases.isNotEmpty) albumsForYou = newReleases;
    if (featuredPlaylistsForYou.isEmpty && albumsForYou.isNotEmpty) featuredPlaylistsForYou = albumsForYou;
    if (newReleases.isEmpty && albumsForYou.isNotEmpty) newReleases = albumsForYou;

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
        final canonicalName = getCleanArtistName(rawArtist);
        final portrait = getArtistPortrait(rawArtist, s.artworkUrl);
        recommendedArtists.add(Artist(
          id: 'artist_${s.id}',
          name: canonicalName,
          artworkUrl: portrait,
          subscribers: 'Artist',
          isVerified: true,
        ));
      }
      if (recommendedArtists.length >= 25) break;
    }

    return HomeData(
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
  }

  @override
  Future<Album> getAlbumDetails(String albumId) async {

    final cleanId = albumId.startsWith('jiosaavn_') ? albumId.substring('jiosaavn_'.length) : albumId;
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

    return Album(
      id: albumId,
      title: decoratedTracks.isNotEmpty ? decoratedTracks.first.album : 'JioSaavn Album',
      artist: decoratedTracks.isNotEmpty ? decoratedTracks.first.artist : 'Various Artists',
      artworkUrl: decoratedTracks.isNotEmpty ? decoratedTracks.first.artworkUrl : '',
      tracks: decoratedTracks,
      songCount: decoratedTracks.length,
      source: 'JioSaavn',
    );
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
