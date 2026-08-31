import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melodrift/core/services/jiosaavn_service.dart';
import 'package:melodrift/core/services/soundcloud_service.dart';
import 'package:melodrift/core/utils/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  
  SharedPreferences.setMockInitialValues({});
  final log = AppLogger('LiveStreamTest');

  group('Live Endpoint Integration Tests', () {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    test('JioSaavn Live Search & Stream Resolution & Connection (320kbps CD Quality)', () async {
      final service = JioSaavnService(dio);
      
      log.info('Calling JioSaavn search...');
      final tracks = await service.search('Vaaste');
      expect(tracks, isNotEmpty);
      
      final firstTrack = tracks.first;
      log.info('Resolving JioSaavn stream URL...');
      final streamUrl = await service.getStreamUrl(firstTrack.id);
      expect(streamUrl, isNotNull);
      
      log.info('Connecting to JioSaavn stream: $streamUrl');
      final response = await dio.head<dynamic>(streamUrl!);
      log.info('JioSaavn stream status code: ${response.statusCode}');
      expect(response.statusCode, 200);
    });

    test('SoundCloud Live Search & Stream Resolution & Connection', () async {
      final soundCloud = SoundCloudService(dio);
      log.info('Calling SoundCloud search...');
      final tracks = await soundCloud.search('chill hip hop');
      expect(tracks, isNotEmpty);

      final firstTrack = tracks.first;
      log.info('Resolving SoundCloud stream URL for track: ${firstTrack.id}...');
      final streamUrl = await soundCloud.getStreamUrl(firstTrack.id);
      expect(streamUrl, isNotNull);

      log.info('Connecting to SoundCloud stream: $streamUrl');
      final response = await dio.get<ResponseBody>(
        streamUrl!,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-1024'},
        ),
      );
      log.info('SoundCloud stream status code: ${response.statusCode}');
      expect(response.statusCode, inInclusiveRange(200, 206));
    });
  });
}
