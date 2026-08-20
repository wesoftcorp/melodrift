import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/youtube_music_remote_source.dart';
import 'taste_profiler_service.dart';
import '../../core/utils/logger.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  final tasteProfiler = ref.watch(tasteProfilerServiceProvider);
  final remoteSource = ref.watch(youtubeMusicRemoteSourceProvider);
  return RecommendationService(tasteProfiler, remoteSource);
});

final personalizedRecommendationsProvider = FutureProvider<PersonalizedFeed>((ref) async {
  final service = ref.watch(recommendationServiceProvider);
  return service.getPersonalizedFeed();
});

class PersonalizedFeed {
  final String title;
  final String subtitle;
  final List<Song> songs;

  const PersonalizedFeed({
    required this.title,
    required this.subtitle,
    required this.songs,
  });
}

class RecommendationService {
  final TasteProfilerService _tasteProfiler;
  final YouTubeMusicRemoteSource _remoteSource;
  final _log = AppLogger('RecommendationService');

  RecommendationService(this._tasteProfiler, this._remoteSource);

  /// Fetch a personalized feed based on user's taste profile
  Future<PersonalizedFeed> getPersonalizedFeed() async {
    try {
      final seeds = _tasteProfiler.getRecentSeeds(limit: 3);
      final topArtists = _tasteProfiler.getTopArtists(limit: 3);

      if (seeds.isNotEmpty) {
        final seed = seeds.first;
        final title = 'Because you listened to ${seed['artist']}';
        final songs = await _remoteSource.getRelatedSongs(seed['id'] as String);
        
        if (songs.isNotEmpty) {
          return PersonalizedFeed(
            title: title,
            subtitle: 'Similar tracks tailored to your vibe',
            songs: songs.take(15).toList(),
          );
        }
      } else if (topArtists.isNotEmpty) {
        final artist = topArtists.first;
        final songs = await _remoteSource.searchSongs('$artist radio mix');
        if (songs.isNotEmpty) {
          return PersonalizedFeed(
            title: 'More from $artist & Similar Artists',
            subtitle: 'Curated mix based on your favorites',
            songs: songs.take(15).toList(),
          );
        }
      }

      // Fallback for new users
      final charts = await _remoteSource.getCharts();
      return PersonalizedFeed(
        title: 'Quick Picks & Trending',
        subtitle: 'Popular hits right now',
        songs: charts.topSongs.take(15).toList(),
      );
    } catch (e) {
      _log.error('Failed to generate personalized feed: $e');
      return const PersonalizedFeed(
        title: 'Recommended For You',
        subtitle: 'Music discovery',
        songs: [],
      );
    }
  }

  /// Generate continuous autoplay recommendations when queue finishes
  Future<List<Song>> getAutoplayQueue(Song lastPlayedSong) async {
    try {
      final related = await _remoteSource.getRelatedSongs(lastPlayedSong.id);
      if (related.isNotEmpty) {
        return related.where((Song s) => s.id != lastPlayedSong.id).take(10).toList();
      }
      return await _remoteSource.searchSongs('${lastPlayedSong.artist} top tracks');
    } catch (e) {
      _log.error('Failed to get autoplay queue: $e');
      return const [];
    }
  }
}
