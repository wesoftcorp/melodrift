abstract class ShareService {
  /// Triggers the native share sheet for a song.
  Future<void> shareSong({
    required String title,
    required String artist,
    String? songId,
  });
}
