import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import 'taste_profiler_service.dart';
import '../../core/utils/logger.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  final tasteProfiler = ref.watch(tasteProfilerServiceProvider);
  final repository = ref.watch(musicRepositoryProvider);
  return RecommendationService(tasteProfiler, repository);
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
  final MusicRepository _repository;
  final _log = AppLogger('RecommendationService');

  RecommendationService(this._tasteProfiler, this._repository);

  /// Fetch a personalized feed based on user's taste profile
  Future<PersonalizedFeed> getPersonalizedFeed() async {
    try {
      final seeds = _tasteProfiler.getRecentSeeds(limit: 3);
      final topArtists = _tasteProfiler.getTopArtists(limit: 3);

      if (seeds.isNotEmpty) {
        final seed = seeds.first;
        final title = 'Because you listened to ${seed['artist']}';
        final songs = await _repository.getRelatedSongs(seed['id'] as String);
        
        if (songs.isNotEmpty) {
          return PersonalizedFeed(
            title: title,
            subtitle: 'Similar tracks tailored to your vibe',
            songs: songs.take(15).toList(),
          );
        }
      } else if (topArtists.isNotEmpty) {
        final artist = topArtists.first;
        final songs = await _repository.searchSongs('$artist songs');
        if (songs.isNotEmpty) {
          return PersonalizedFeed(
            title: 'More from $artist & Similar Artists',
            subtitle: 'Curated based on your most played artists',
            songs: songs.take(15).toList(),
          );
        }
      }
    } catch (e, s) {
      _log.error('Failed to generate personalized feed: $e', e, s);
    }

    // Default fallback feed
    try {
      final defaultSongs = await _repository.searchSongs('trending hits');
      return PersonalizedFeed(
        title: 'Fresh Picks For You',
        subtitle: 'Trending global and Indian tracks',
        songs: defaultSongs.take(15).toList(),
      );
    } catch (_) {
      return const PersonalizedFeed(
        title: 'Recommended For You',
        subtitle: 'Start listening to see personalized recommendations',
        songs: [],
      );
    }
  }

  /// Returns seamless autoplay recommendations when queue ends
  Future<List<Song>> getAutoplayQueue(Song? currentSong) async {
    if (currentSong == null) return const [];
    try {
      final related = await _repository.getRelatedSongs(currentSong.id);
      if (related.isNotEmpty) return related;

      final artistQuery = '${currentSong.artist} songs';
      final artistSongs = await _repository.searchSongs(artistQuery);
      return artistSongs.where((s) => s.id != currentSong.id).toList();
    } catch (e) {
      _log.error('Autoplay queue generation error: $e');
      return const [];
    }
  }
}

