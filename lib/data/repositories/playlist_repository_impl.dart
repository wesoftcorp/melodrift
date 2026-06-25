import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/local_music_source.dart';
import '../models/local_models.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final localSource = ref.watch(localMusicSourceProvider);
  return PlaylistRepositoryImpl(localSource);
});

final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.watchPlaylists();
});

class PlaylistRepositoryImpl implements PlaylistRepository {
  final LocalMusicSource _localSource;

  PlaylistRepositoryImpl(this._localSource);

  LocalSong _mapSongToLocal(Song song) {
    return LocalSong()
      ..songId = song.id
      ..title = song.title
      ..artist = song.artist
      ..album = song.album
      ..durationMs = song.duration.inMilliseconds
      ..artworkUrl = song.artworkUrl
      ..videoId = song.videoId
      ..isDownloaded = false;
  }

  Song _mapLocalToSong(LocalSong local) {
    return Song(
      id: local.songId,
      title: local.title,
      artist: local.artist,
      album: local.album,
      duration: Duration(milliseconds: local.durationMs),
      artworkUrl: local.artworkUrl,
      streamUrl: local.filePath,
      videoId: local.videoId,
    );
  }

  Playlist _mapLocalToPlaylist(LocalPlaylist local) {
    return Playlist(
      id: local.playlistId,
      title: local.title,
      description: local.description,
      artworkUrl: local.artworkUrl,
      trackCount: local.trackCount,
      songs: local.songs.map((s) => _mapLocalToSong(s)).toList(),
      isYouTube: local.isYouTube,
      isLocal: local.isLocal,
    );
  }

  LocalPlaylist _mapPlaylistToLocal(Playlist p) {
    return LocalPlaylist()
      ..playlistId = p.id
      ..title = p.title
      ..description = p.description
      ..artworkUrl = p.artworkUrl
      ..trackCount = p.trackCount
      ..isYouTube = p.isYouTube
      ..isLocal = p.isLocal;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final list = await _localSource.getAllPlaylists();
    return list.map((l) => _mapLocalToPlaylist(l)).toList();
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final local = await _localSource.getPlaylist(id);
    if (local == null) return null;
    return _mapLocalToPlaylist(local);
  }

  @override
  Future<void> createPlaylist(Playlist playlist) async {
    final local = _mapPlaylistToLocal(playlist);
    await _localSource.savePlaylist(local);
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _localSource.deletePlaylist(id);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final localSong = _mapSongToLocal(song);
    await _localSource.addSongToPlaylist(playlistId, localSong);
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _localSource.removeSongFromPlaylist(playlistId, songId);
  }

  @override
  Stream<List<Playlist>> watchPlaylists() {
    return _localSource.watchAllPlaylists().asyncMap((list) async {
      final List<Playlist> results = [];
      for (final l in list) {
        await l.songs.load();
        results.add(_mapLocalToPlaylist(l));
      }
      return results;
    });
  }
}
