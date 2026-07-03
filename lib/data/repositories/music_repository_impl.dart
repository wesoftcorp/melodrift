import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/youtube_music_remote_source.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/jiosaavn_service.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final remoteSource = ref.watch(youtubeMusicRemoteSourceProvider);
  return MusicRepositoryImpl(remoteSource);
});

class MusicRepositoryImpl implements MusicRepository {
  final YouTubeMusicRemoteSource _remoteSource;

  MusicRepositoryImpl(this._remoteSource);

  @override
  Future<List<Song>> searchSongs(String query) async {
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(query);
    return tracks.map((t) => Song(
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
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(query);
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
    return uniqueAlbums.values.toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    final jioSaavn = getIt<JioSaavnService>();
    final tracks = await jioSaavn.search(query);
    final Map<String, Artist> uniqueArtists = {};
    for (final t in tracks) {
      final firstArtist = t.artist.split(',').first.trim();
      final artistId = 'artist_${t.id.startsWith('jiosaavn_') ? t.id.substring(10) : t.id}';
      if (firstArtist.isNotEmpty && !uniqueArtists.containsKey(firstArtist)) {
        uniqueArtists[firstArtist] = Artist(
          id: artistId,
          name: firstArtist,
          artworkUrl: t.artworkUrl,
          subscribers: 'JioSaavn Artist',
          isVerified: true,
        );
      }
    }
    return uniqueArtists.values.toList();
  }

  @override
  Future<HomeData> getHomeFeed({String? language}) => _remoteSource.getHomeFeed(language: language);

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
    final tracks = await jioSaavn.search(cleanId);
    
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
    final jioSaavn = getIt<JioSaavnService>();
    
    // 1. Direct ID lookup
    final cleanId = videoId.startsWith('jiosaavn_') ? videoId.substring('jiosaavn_'.length) : videoId;
    final isSaavnId = RegExp(r'^[a-zA-Z0-9_\-]{8,15}$').hasMatch(cleanId) && !RegExp(r'^[0-9]+$').hasMatch(cleanId);
    
    if (isSaavnId) {
      try {
        final url = await jioSaavn.getStreamUrl(cleanId);
        if (url != null && url.isNotEmpty) {
          return url;
        }
      } catch (_) {}
    }

    // 2. Search query fallback
    try {
      final candidates = await jioSaavn.search(videoId);
      if (candidates.isNotEmpty) {
        final url = await jioSaavn.getStreamUrl(candidates.first.id);
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    } catch (_) {}

    throw StateError('Could not resolve JioSaavn stream URL for track: $videoId');
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
    final tracks = await jioSaavn.search('trending');
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
