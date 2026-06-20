import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<HomeData> getHomeFeed() async {
    // Quick Picks: Fetch popular songs
    final quickPicks = await searchSongs('popular hits');

    // New Releases: Search for 2026 new albums
    final newReleases = await searchAlbums('latest albums 2026');

    // Charts: Popular trending music
    final charts = await searchSongs('trending music');

    // Moods: Static premium categories
    final moods = getMoodGenreCategories();

    return HomeData(
      quickPicks: quickPicks.take(10).toList(),
      newReleases: newReleases.take(6).toList(),
      charts: charts.take(10).toList(),
      moods: moods,
    );
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
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly.toList()
      ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    
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
      MoodCategory(id: 'workout', title: 'Workout'),
      MoodCategory(id: 'focus', title: 'Focus'),
      MoodCategory(id: 'relax', title: 'Relax'),
      MoodCategory(id: 'party', title: 'Party'),
      MoodCategory(id: 'romance', title: 'Romance'),
      MoodCategory(id: 'sad', title: 'Sad/Melancholy'),
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
    return tracks;
  }

  /// Closes resources
  void dispose() {
    _yt.close();
  }
}
