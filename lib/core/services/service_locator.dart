import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'jiosaavn_service.dart';
import 'soundcloud_service.dart';
import 'spotify_service.dart';
import 'jiosaavn_lyrics_provider.dart';
import 'lrclib_provider.dart';
import 'youlyplus_provider.dart';
import 'kugou_provider.dart';
import 'lyrics_registry.dart';
import 'apple_music_service.dart';
import 'unified_stream_resolver.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register Dio with default timeouts and secure SSL handling
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  
  if (dio.httpClientAdapter is IOHttpClientAdapter) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }
  
  getIt.registerLazySingleton<Dio>(() => dio);
  
  // Register JioSaavnService
  getIt.registerLazySingleton<JioSaavnService>(() => JioSaavnService(getIt<Dio>()));

  // Register SoundCloudService
  getIt.registerLazySingleton<SoundCloudService>(() => SoundCloudService(getIt<Dio>()));

  // Register SpotifyService
  getIt.registerLazySingleton<SpotifyService>(() => SpotifyService(getIt<Dio>()));

  // Register AppleMusicService
  getIt.registerLazySingleton<AppleMusicService>(() => AppleMusicService(getIt<Dio>()));

  // Register UnifiedStreamResolver
  getIt.registerLazySingleton<UnifiedStreamResolver>(() => UnifiedStreamResolver(
    getIt<JioSaavnService>(),
    getIt<SoundCloudService>(),
  ));

  // Register LyricsRegistry and its providers
  getIt.registerLazySingleton<LyricsRegistry>(() => LyricsRegistry([
    JioSaavnLyricsProvider(getIt<Dio>()),
    LrcLibProvider(getIt<Dio>()),
    YouLyPlusProvider(getIt<Dio>()),
    KuGouProvider(getIt<Dio>()),
  ]));
}
