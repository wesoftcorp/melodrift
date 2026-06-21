abstract class ShareService {
  /// Fetches a unified sharing link from Odesli (song.link) and triggers the native share sheet.
  Future<void> shareSong({
    required String title,
    required String artist,
    required String youtubeId,
  });
}
