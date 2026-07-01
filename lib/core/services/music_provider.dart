import 'music_track.dart';

abstract class MusicProvider {
  String get name;
  Future<List<MusicTrack>> search(String query);
  Future<String?> getStreamUrl(String trackId);
  Future<List<MusicTrack>> browse(String browseId);
}
