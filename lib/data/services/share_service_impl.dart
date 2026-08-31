import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/logger.dart';
import '../../domain/services/share_service.dart';

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareServiceImpl();
});

class ShareServiceImpl implements ShareService {
  final _log = AppLogger('ShareService');

  ShareServiceImpl();

  @override
  Future<void> shareSong({
    required String title,
    required String artist,
    String? songId,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    final text = 'Listening to "$cleanTitle" by $cleanArtist on Melodrift 🎵';

    try {
      await Share.share(
        text,
        subject: '$cleanTitle - $cleanArtist',
      );
    } catch (e, s) {
      _log.error('Failed to trigger native share: $e', e, s);
    }
  }
}
