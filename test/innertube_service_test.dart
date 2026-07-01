import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:melodrift/core/services/innertube_service.dart';

void main() {
  group('InnerTubeService Parser Tests', () {
    test('should parse mock response correctly into MusicTracks', () async {
      // Mock Dio response
      final mockData = {
        'contents': {
          'tabbedSearchResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'musicShelfRenderer': {
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'Closer (feat. Halsey)'}
                                          ]
                                        }
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'The Chainsmokers'},
                                            {'text': ' • '},
                                            {'text': 'Collage'},
                                            {'text': ' • '},
                                            {'text': '4:06'}
                                          ]
                                        }
                                      }
                                    }
                                  ],
                                  'playlistItemData': {'videoId': 'r7zTKRonHXM'},
                                  'thumbnail': {
                                    'musicThumbnailRenderer': {
                                      'thumbnail': {
                                        'thumbnails': [
                                          {'url': 'https://example.com/art.jpg', 'width': 120, 'height': 120}
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
      final tracks = await service.search('closer');

      expect(tracks, hasLength(1));
      final track = tracks.first;
      expect(track.id, 'r7zTKRonHXM');
      expect(track.title, 'Closer (feat. Halsey)');
      expect(track.artist, 'The Chainsmokers');
      expect(track.album, 'Collage');
      expect(track.duration, const Duration(minutes: 4, seconds: 6));
      expect(track.artworkUrl, 'https://example.com/art.jpg');
      expect(track.source, 'youtube');
      expect(track.extras['videoId'], 'r7zTKRonHXM');
    });

    test('should parse runs with multiple artists and time-like album names correctly', () async {
      final mockData = {
        'contents': {
          'tabbedSearchResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'musicShelfRenderer': {
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'Closer'}
                                          ]
                                        }
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {
                                          'runs': [
                                            {'text': 'Chris Brown'},
                                            {'text': ' • '},
                                            {'text': '11:11'}, // Time-like album name!
                                            {'text': ' • '},
                                            {'text': '2:12'}
                                          ]
                                        }
                                      }
                                    }
                                  ],
                                  'playlistItemData': {'videoId': 'WTuatkwD35Q'},
                                  'thumbnail': {
                                    'musicThumbnailRenderer': {
                                      'thumbnail': {
                                        'thumbnails': [
                                          {'url': 'https://example.com/art.jpg'}
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
      final tracks = await service.search('closer');

      expect(tracks, hasLength(1));
      final track = tracks.first;
      expect(track.artist, 'Chris Brown');
      expect(track.album, '11:11'); // Verify album is parsed correctly
      expect(track.duration, const Duration(minutes: 2, seconds: 12)); // Verify duration is parsed correctly
    });
  });
}

// Simple Dio Mock
class DioMock implements Dio {
  final Map<String, dynamic> mockResponseData;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
