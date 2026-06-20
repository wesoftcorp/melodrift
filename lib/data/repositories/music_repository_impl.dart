import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/charts_data.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/youtube_music_remote_source.dart';


final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final remoteSource = ref.watch(youtubeMusicRemoteSourceProvider);
  return MusicRepositoryImpl(remoteSource);
});

class MusicRepositoryImpl implements MusicRepository {
  final YouTubeMusicRemoteSource _remoteSource;

  MusicRepositoryImpl(this._remoteSource);

  @override
  Future<List<Song>> searchSongs(String query) => _remoteSource.searchSongs(query);

  @override
  Future<List<Album>> searchAlbums(String query) => _remoteSource.searchAlbums(query);

  @override
  Future<List<Artist>> searchArtists(String query) => _remoteSource.searchArtists(query);

  @override
  Future<HomeData> getHomeFeed() => _remoteSource.getHomeFeed();

  @override
  Future<Album> getAlbumDetails(String albumId) => _remoteSource.getAlbumDetails(albumId);

  @override
  Future<Artist> getArtistDetails(String artistId) => _remoteSource.getArtistDetails(artistId);

  @override
  Future<Playlist> getPlaylistDetails(String playlistId) => _remoteSource.getPlaylistDetails(playlistId);

  @override
  Future<String> getStreamUrl(String videoId, {String quality = 'High'}) =>
      _remoteSource.getStreamUrl(videoId, quality);

  @override
  Future<String> getVideoStreamUrl(String videoId) => _remoteSource.getVideoStreamUrl(videoId);

  @override
  Future<List<Song>> getRelatedSongs(String videoId) => _remoteSource.getRelatedSongs(videoId);

  @override
  Future<ChartsData> getCharts({String? country}) => _remoteSource.getCharts(country);
}
