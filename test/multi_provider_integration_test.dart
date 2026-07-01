import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:melodrift/core/services/jiosaavn_service.dart';
import 'package:melodrift/core/services/lyrics_provider.dart';
import 'package:melodrift/core/services/lrclib_provider.dart';
import 'package:melodrift/core/services/youlyplus_provider.dart';
import 'package:melodrift/core/services/kugou_provider.dart';
import 'package:melodrift/core/services/lyrics_registry.dart';
import 'package:melodrift/domain/entities/lyrics.dart';

void main() {
  group('JioSaavnService Tests', () {
    test('should parse search results correctly', () async {
      final mockData = {
        'success': true,
        'data': {
          'results': [
            {
              'id': 'saavn_123',
              'name': 'Closer',
              'primaryArtists': 'The Chainsmokers feat. Halsey',
              'album': {'name': 'Collage'},
              'duration': '246',
              'image': [
                {'quality': '150x150', 'link': 'https://example.com/150.jpg'},
                {'quality': '500x500', 'link': 'https://example.com/500.jpg'}
              ]
            }
          ]
        }
      };

      final dio = DioMock(mockData);
      final service = JioSaavnService(dio);
      final tracks = await service.search('closer');

      expect(tracks, hasLength(1));
      final track = tracks.first;
      expect(track.id, 'saavn_123');
      expect(track.title, 'Closer');
      expect(track.artist, 'The Chainsmokers feat. Halsey');
      expect(track.album, 'Collage');
      expect(track.duration, const Duration(seconds: 246));
      expect(track.artworkUrl, 'https://example.com/500.jpg');
      expect(track.source, 'jiosaavn');
    });

    test('should resolve 320kbps stream URL', () async {
      final mockData = {
        'success': true,
        'data': [
          {
            'id': 'saavn_123',
            'downloadUrl': [
              {'quality': '160kbps', 'link': 'https://example.com/160.mp3'},
              {'quality': '320kbps', 'link': 'https://example.com/320.mp3'}
            ]
          }
        ]
      };

      final dio = DioMock(mockData);
      final service = JioSaavnService(dio);
      final url = await service.getStreamUrl('saavn_123');

      expect(url, 'https://example.com/320.mp3');
    });
  });

  group('Lyrics Providers and Registry Tests', () {
    test('LrcLibProvider should parse synced lyrics', () async {
      final mockData = [
        {
          'syncedLyrics': '[00:10.50] Hello World\n[00:15.00] Second Line',
          'plainLyrics': 'Hello World\nSecond Line'
        }
      ];

      final dio = DioMock(mockData);
      final provider = LrcLibProvider(dio);
      final lyrics = await provider.getLyrics('hello', 'world', const Duration(seconds: 120));

      expect(lyrics, hasLength(2));
      expect(lyrics[0].timeMs, 10500);
      expect(lyrics[0].text, 'Hello World');
      expect(lyrics[1].timeMs, 15000);
      expect(lyrics[1].text, 'Second Line');
    });

    test('YouLyPlusProvider should parse plain lyrics if no synced available', () async {
      final mockData = {
        'plainLyrics': 'Line One\nLine Two'
      };

      final dio = DioMock(mockData);
      final provider = YouLyPlusProvider(dio);
      final lyrics = await provider.getLyrics('hello', 'world', const Duration(seconds: 120));

      expect(lyrics, hasLength(2));
      expect(lyrics[0].text, 'Line One');
      expect(lyrics[0].timeMs, 0);
      expect(lyrics[1].text, 'Line Two');
      expect(lyrics[1].timeMs, 3000);
    });

    test('KuGouProvider should download and base64 decode lyrics', () async {
      // First call is search, second call is download
      final dio = MultiCallDioMock([
        // Search response
        {
          'candidates': [
            {'id': '111', 'accesskey': 'abc'}
          ]
        },
        // Download response (Base64 for "[00:12.34] Kinda like it")
        {
          'content': 'WzAwOjEyLjM0XSBLaW5kYSBsaWtlIGl0'
        }
      ]);

      final provider = KuGouProvider(dio);
      final lyrics = await provider.getLyrics('hello', 'world', const Duration(seconds: 120));

      expect(lyrics, hasLength(1));
      expect(lyrics[0].text, 'Kinda like it');
      expect(lyrics[0].timeMs, 12340);
    });

    test('LyricsRegistry should try providers in sequence and return first success', () async {
      final lrcLib = MockLyricsProvider('lrclib', []);
      final youLy = MockLyricsProvider('youlyplus', [
        const LyricLine(timeMs: 5000, text: 'YouLyPlus Content')
      ]);
      final kuGou = MockLyricsProvider('kugou', [
        const LyricLine(timeMs: 8000, text: 'KuGou Content')
      ]);

      final registry = LyricsRegistry([lrcLib, youLy, kuGou]);
      final lyrics = await registry.getLyrics('test', 'song', const Duration(seconds: 180));

      expect(lyrics, hasLength(1));
      expect(lyrics[0].text, 'YouLyPlus Content');
      expect(lyrics[0].timeMs, 5000);
      
      // Verify registry stopped and did not query KuGou
      expect(lrcLib.callCount, 1);
      expect(youLy.callCount, 1);
      expect(kuGou.callCount, 0);
    });
  });
}

// Simple Dio Mock for single calls
class DioMock implements Dio {
  final dynamic mockResponseData;
  DioMock(this.mockResponseData);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return Response<T>(
      data: mockResponseData as T,
      headers: Headers(),
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Dio Mock supporting sequential calls
class MultiCallDioMock implements Dio {
  final List<dynamic> responses;
  int _callIndex = 0;

  MultiCallDioMock(this.responses);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final res = responses[_callIndex];
    _callIndex = (_callIndex + 1) % responses.length;
    return Response<T>(
      data: res as T,
      headers: Headers(),
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock LyricsProvider for sequential testing
class MockLyricsProvider implements LyricsProvider {
  @override
  final String name;
  final List<LyricLine> responseLyrics;
  int callCount = 0;

  MockLyricsProvider(this.name, this.responseLyrics);

  @override
  Future<List<LyricLine>> getLyrics(String title, String artist, Duration duration) async {
    callCount++;
    return responseLyrics;
  }
}
