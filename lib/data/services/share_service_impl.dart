import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/share_service.dart';

final shareServiceProvider = Provider<ShareService>((ref) {
  final dio = Dio(); // Reuse/create Dio client
  return ShareServiceImpl(dio);
});

class ShareServiceImpl implements ShareService {
  final Dio _dio;

  ShareServiceImpl(this._dio);

  @override
  Future<void> shareSong({
    required String title,
    required String artist,
    required String youtubeId,
  }) async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=$youtubeId';
    String shareUrl = youtubeUrl;

    try {
      // Query Odesli API for a premium song.link page
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.odesli.co/v1.1/links',
        queryParameters: {'url': youtubeUrl},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final pageUrl = data['pageUrl'] as String?;
        if (pageUrl != null && pageUrl.isNotEmpty) {
          shareUrl = pageUrl;
        }
      }
    } catch (_) {
      // Fallback silently to direct YouTube link if network or Odesli API fails
    }

    // Launch native platform share sheet
    await Share.share(
      'Check out "$title" by $artist: $shareUrl',
      subject: 'Share Song',
    );
  }
}
