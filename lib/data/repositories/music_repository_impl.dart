import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/youtube_music_remote_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final sourceSetting = prefs.getString('primary_music_source') ?? 'YouTube Music';
    if (sourceSetting == 'JioSaavn') {
      final jioSaavn = getIt<JioSaavnService>();
      final tracks = await jioSaavn.search(query);
      return tracks.map((t) => Song(
        id: t.id,
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
    return _remoteSource.searchSongs(query);
  }

  @override
  Future<List<Album>> searchAlbums(String query) => _remoteSource.searchAlbums(query);

  @override
  Future<List<Artist>> searchArtists(String query) => _remoteSource.searchArtists(query);

  @override
  Future<HomeData> getHomeFeed({String? language}) => _remoteSource.getHomeFeed(language: language);

  @override
  Future<Album> getAlbumDetails(String albumId) => _remoteSource.getAlbumDetails(albumId);

  @override
  Future<Artist> getArtistDetails(String artistId) => _remoteSource.getArtistDetails(artistId);

  @override
  Future<Playlist> getPlaylistDetails(String playlistId) => _remoteSource.getPlaylistDetails(playlistId);

  @override
  Future<String> getStreamUrl(String videoId, {String quality = 'High'}) async {
    final prefs = await SharedPreferences.getInstance();
    final sourceSetting = prefs.getString('primary_music_source') ?? 'YouTube Music';
    if (sourceSetting == 'JioSaavn' || !videoId.contains(RegExp(r'^[a-zA-Z0-9_-]{11}$'))) {
      final jioSaavn = getIt<JioSaavnService>();
      final url = await jioSaavn.getStreamUrl(videoId);
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return _remoteSource.getStreamUrl(videoId, quality);
  }


  @override
  Future<String> getVideoStreamUrl(String videoId) => _remoteSource.getVideoStreamUrl(videoId);

  @override
  Future<List<Song>> getRelatedSongs(String videoId) => _remoteSource.getRelatedSongs(videoId);

  @override
  Future<ChartsData> getCharts({String? country}) => _remoteSource.getCharts(country);

  @override
  Future<List<String>> getSearchSuggestions(String query) => _remoteSource.getSearchSuggestions(query);
}
