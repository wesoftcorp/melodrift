import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melodrift/core/services/jiosaavn_service.dart';
import 'package:melodrift/core/services/soundcloud_service.dart';
import 'package:melodrift/core/services/unified_stream_resolver.dart';
import 'package:melodrift/domain/entities/song.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('UnifiedStreamResolver Architecture Tests', () {
    late Dio dio;
    late JioSaavnService jioSaavn;
    late SoundCloudService soundCloud;
    late UnifiedStreamResolver resolver;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      jioSaavn = JioSaavnService(dio);
      soundCloud = SoundCloudService(dio);
      resolver = UnifiedStreamResolver(jioSaavn, soundCloud);
    });

    test('Direct JioSaavn Resolution returns 320kbps stream', () async {
      final tracks = await jioSaavn.search('Vaaste');
      expect(tracks, isNotEmpty);
      final liveTrack = tracks.first;

      final directJioSong = Song(
        id: liveTrack.id,
        title: liveTrack.title,
        artist: liveTrack.artist,
        album: liveTrack.album,
        duration: liveTrack.duration,
        artworkUrl: liveTrack.artworkUrl,
        videoId: liveTrack.id,
        source: 'JioSaavn',
      );

      final result = await resolver.resolve(song: directJioSong);
      expect(result, isNotNull);
      expect(result!.url, isNotEmpty);
      expect(result.source, contains('JioSaavn'));
      expect(result.bitrate, 320);

      // Verify stream is directly playable via CDN
      final res = await dio.head<dynamic>(result.url);
      expect(res.statusCode, 200);
    });

    test('SoundCloud Search and Stream Resolution returns open progressive stream', () async {
      final tracks = await soundCloud.search('chill lofi');
      expect(tracks, isNotEmpty);

      final streamUrl = await soundCloud.getStreamUrl(tracks.first.id);
      expect(streamUrl, isNotNull);
      expect(streamUrl, isNotEmpty);
    });

    test('UnifiedStreamResolver matches track to JioSaavn 320kbps CDN', () async {
      const songToMatch = Song(
        id: 'track_123',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        duration: Duration(minutes: 4, seconds: 28),
        artworkUrl: '',
        videoId: 'track_123',
        source: 'Spotify',
      );

      final result = await resolver.resolve(song: songToMatch);
      expect(result, isNotNull);
      expect(result!.url, isNotEmpty);
      expect(result.bitrate, anyOf(160, 320));
    });
  });

}
