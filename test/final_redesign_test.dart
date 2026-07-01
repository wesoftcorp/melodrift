import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:melodrift/core/services/innertube_service.dart';
import 'package:melodrift/core/services/jiosaavn_service.dart';
import 'package:melodrift/core/services/apple_music_service.dart';

void main() {
  group('InnerTubeService Browse Tests', () {
    test('should recursively find and parse musicResponsiveListItemRenderer', () async {
      // Mock nested browse response containing a list item renderer deep inside the tree
      final mockData = {
        'contents': {
          'singleColumnBrowseResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'musicPlaylistShelfRenderer': {
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'Mock Browse Song'}
                                          ]
                                        }
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'Mock Browse Artist'},
                                            {'text': ' • '},
                                            {'text': 'Mock Browse Album'},
                                            {'text': ' • '},
                                            {'text': '3:30'}
                                          ]
                                        }
                                      }
                                    }
                                  ],
                                  'playlistItemData': {'videoId': 'videoId_123'},
                                  'thumbnail': {
                                    'musicThumbnailRenderer': {
                                      'thumbnail': {
                                        'thumbnails': [
                                          {'url': 'https://example.com/browse.jpg'}
                                        ]
                                      }
                                    }
                                  }
                                }
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        }
      };

      final dio = DioMock(mockData);
      final service = InnerTubeService(dio);
      final tracks = await service.browse('VLPL_mock_id');

      expect(tracks, hasLength(1));
      final track = tracks.first;
      expect(track.id, 'videoId_123');
      expect(track.title, 'Mock Browse Song');
      expect(track.artist, 'Mock Browse Artist');
      expect(track.album, 'Mock Browse Album');
      expect(track.duration, const Duration(minutes: 3, seconds: 30));
      expect(track.artworkUrl, 'https://example.com/browse.jpg');
    });
  });

  group('JioSaavnService Browse Tests', () {
    test('should query album/playlist details and parse songs list', () async {
      final mockData = {
        'success': true,
        'data': {
          'songs': [
            {
              'id': 'saavn_browse_1',
              'name': 'Browse JioSaavn Song',
              'primaryArtists': 'Browse JioSaavn Artist',
              'album': {'name': 'Browse JioSaavn Album'},
              'duration': '180',
              'image': [
                {'link': 'https://example.com/browse_saavn.jpg'}
              ]
            }
          ]
        }
      };

      final dio = DioMock(mockData);
      final service = JioSaavnService(dio);
      final tracks = await service.browse('album_123');

      expect(tracks, hasLength(1));
      final track = tracks.first;
      expect(track.id, 'saavn_browse_1');
      expect(track.title, 'Browse JioSaavn Song');
      expect(track.artist, 'Browse JioSaavn Artist');
      expect(track.album, 'Browse JioSaavn Album');
      expect(track.duration, const Duration(seconds: 180));
      expect(track.artworkUrl, 'https://example.com/browse_saavn.jpg');
    });
  });

  group('AppleMusicService Tests', () {
    test('should search iTunes and parse motion artwork m3u8 URL from Apple Music HTML', () async {
      // First call: iTunes search response
      // Second call: Apple Music crawled web page HTML string containing an m3u8 URL
      final dio = MultiCallDioMock([
        // iTunes search
        {
          'results': [
            {
              'collectionViewUrl': 'https://music.apple.com/us/album/mock-album/12345'
            }
          ]
        },
        // Apple Music page HTML content containing an editorialVideo m3u8 link
        '<html><body><script>HydrationData = {"editorialVideo": "https://video-ssl.itunes.apple.com/apple-assets-us-std-000001/Video123/v4/ea/12/34/ea12345-editorialVideo.m3u8"}</script></body></html>'
      ]);

      final service = AppleMusicService(dio);
      final url = await service.getMotionArtworkUrl('Mock Title', 'Mock Artist');

      expect(url, 'https://video-ssl.itunes.apple.com/apple-assets-us-std-000001/Video123/v4/ea/12/34/ea12345-editorialVideo.m3u8');
    });

    test('should return null if no motion artwork regex match found on page', () async {
      final dio = MultiCallDioMock([
        // iTunes search
        {
          'results': [
            {
              'collectionViewUrl': 'https://music.apple.com/us/album/mock-album/12345'
            }
          ]
        },
        // HTML page without any m3u8 video URL
        '<html><body><h1>No motion artwork here</h1></body></html>'
      ]);

      final service = AppleMusicService(dio);
      final url = await service.getMotionArtworkUrl('Mock Title', 'Mock Artist');

      expect(url, isNull);
    });
  });
}

// Simple Dio Mock
class DioMock implements Dio {
  final dynamic mockResponseData;
  DioMock(this.mockResponseData);

  @override
  Future<Response<T>> post<T>(
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

// MultiCall Dio Mock
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
