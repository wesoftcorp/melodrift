import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melodrift/core/services/jiosaavn_service.dart';
import 'package:melodrift/data/datasources/youtube_music_remote_source.dart';
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

    test('JioSaavn Live Search & Stream Resolution & Connection', () async {
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

    test('YouTube Live Stream Resolution & Connection (Vercel)', () async {
      final remoteSource = YouTubeMusicRemoteSource();
      final streamUrl = await remoteSource.getStreamUrl('dQw4w9WgXcQ', 'High', preferLocal: false);
      expect(streamUrl, isNotEmpty);
      
      log.info('Connecting to Vercel resolved YouTube stream: $streamUrl');
      try {
        final response = await dio.head<dynamic>(
          streamUrl,
          options: Options(headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          }),
        );
        log.info('YouTube Vercel stream status: ${response.statusCode}');
        expect(response.statusCode, 200);
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 403) {
          log.info('YouTube Vercel stream returned 403 (Expected due to YouTube IP-locking).');
        } else {
          log.error('YouTube Vercel stream connection failed: $e');
          fail('Vercel resolved stream is not playable: $e');
        }
      }
    });

    test('YouTube Live Stream Resolution & Connection (Local Client Racing)', () async {
      final remoteSource = YouTubeMusicRemoteSource();
      final streamUrl = await remoteSource.getStreamUrl('dQw4w9WgXcQ', 'High', preferLocal: true);
      expect(streamUrl, isNotEmpty);
      
      log.info('Connecting to locally resolved YouTube stream: $streamUrl');
      try {
        final response = await dio.head<dynamic>(
          streamUrl,
          options: Options(headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          }),
        );
        log.info('YouTube locally resolved stream status: ${response.statusCode}');
        expect(response.statusCode, 200);
      } catch (e) {
        log.error('YouTube locally resolved stream connection failed: $e');
        fail('Locally resolved stream is not playable: $e');
      }
    });
  });
}
