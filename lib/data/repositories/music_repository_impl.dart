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

    Future<List<Song>> fetchJio(String q, {int limit = 30}) async {
      try {
        final tracks = await jioSaavn.search(q, limit: limit).timeout(const Duration(seconds: 6), onTimeout: () => []);
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

    Future<List<Song>> fetchSpotifyTop() async {
      try {
        final res = await spotify.fetchPlaylist('37i9dQZF1DXcBWIGoYBM5M').timeout(const Duration(seconds: 4), onTimeout: () => null);
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

    await Future.wait([
      fetchJio('trending top hits$langSuffix').then((res) => quickPicks = res),
      fetchJioAlbums('latest releases 2024$langSuffix').then((res) => newReleases = res),
      fetchJio('top 50 hindi weekly$langSuffix').then((res) => charts = res),
      fetchJio('romantic love songs$langSuffix').then((res) => listenAgain = res),
      fetchJio('viral songs trending$langSuffix').then((res) => trendingSongs = res),
      fetchJio('punjabi bollywood blockbuster$langSuffix').then((res) => indianMusic = res),
      fetchJio('retro 90s classic evergreen$langSuffix').then((res) => forgottenFavorites = res),
      fetchJioAlbums('superhit album songs$langSuffix').then((res) => albumsForYou = res),
      fetchJioAlbums('party dance mix playlists$langSuffix').then((res) => featuredPlaylistsForYou = res),
      fetchSoundCloud('lofi chill remix beats').then((res) => soundCloudLounge = res),
      fetchSpotifyTop().then((res) => spotifyTopHits = res),
      Future(() async {
        final responses = await Future.wait([
          fetchJio('hindi trending top hits$langSuffix', limit: 30),
          fetchJio('bollywood blockbuster chartbusters$langSuffix', limit: 30),
          fetchJio('latest bollywood superhit songs$langSuffix', limit: 30),
          fetchJio('top 50 hindi weekly hits$langSuffix', limit: 30),
        ]);
        final Map<String, Song> unique = {};
        for (final r in responses) {
          for (final s in r) {
            if (!unique.containsKey(s.id)) {
              unique[s.id] = s;
            }
          }
        }
        top100India = unique.values.toList();
      }),
      Future(() async {
        final responses = await Future.wait([
          fetchJio('billboard hot 100 global top hits english', limit: 30),
          fetchJio('international pop global viral hits english', limit: 30),
          fetchJio('today top hits global english songs', limit: 30),
        ]);
        final Map<String, Song> unique = {};
        for (final r in responses) {
          for (final s in r) {
            if (!unique.containsKey(s.id)) {
              unique[s.id] = s;
            }
          }
        }
        top100International = unique.values.toList();
      }),
      fetchJio('international pop global viral hits english', limit: 35).then((res) => internationalHits = res),
      fetchJio('latest punjabi party hits banger', limit: 35).then((res) => punjabiHits = res),
      fetchJio('romantic melodies soulful love arijit shreya', limit: 35).then((res) => romanticMelodies = res),
      fetchJio('bollywood dance party club edm mix', limit: 35).then((res) => partyDanceMix = res),
    ]);

    // Ensure every single section is packed and never empty
    if (top100India.isEmpty) {

      top100India = [...trendingSongs, ...quickPicks, ...charts, ...indianMusic];
    }
    if (top100International.isEmpty) {
      top100International = [...spotifyTopHits, ...internationalHits];
    }
    if (internationalHits.isEmpty) {
      internationalHits = spotifyTopHits.isNotEmpty ? spotifyTopHits : quickPicks;
    }
    if (punjabiHits.isEmpty) {
      punjabiHits = indianMusic.isNotEmpty ? indianMusic : quickPicks;
    }
    if (romanticMelodies.isEmpty) {
      romanticMelodies = listenAgain.isNotEmpty ? listenAgain : quickPicks;
    }
    if (partyDanceMix.isEmpty) {
      partyDanceMix = trendingSongs.isNotEmpty ? trendingSongs : quickPicks;
    }
    if (soundCloudLounge.isEmpty) {
      soundCloudLounge = forgottenFavorites.isNotEmpty ? forgottenFavorites : quickPicks;
    }
    if (spotifyTopHits.isEmpty) {
      spotifyTopHits = internationalHits.isNotEmpty ? internationalHits : quickPicks;
    }
    if (albumsForYou.isEmpty && newReleases.isNotEmpty) {
      albumsForYou = newReleases;
    }
    if (featuredPlaylistsForYou.isEmpty && albumsForYou.isNotEmpty) {
      featuredPlaylistsForYou = albumsForYou;
    }
    if (newReleases.isEmpty && albumsForYou.isNotEmpty) {
      newReleases = albumsForYou;
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
