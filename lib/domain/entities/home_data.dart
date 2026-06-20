import 'song.dart';
import 'album.dart';
import 'mood_category.dart';

class HomeData {
  final List<Song> quickPicks;
  final List<Album> newReleases;
  final List<Song> charts;
  final List<MoodCategory> moods;

  const HomeData({
    required this.quickPicks,
    required this.newReleases,
    required this.charts,
    required this.moods,
  });
}
