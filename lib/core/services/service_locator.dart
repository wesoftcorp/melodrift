import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'youtube_auth_service.dart';
import 'innertube_service.dart';
import 'jiosaavn_service.dart';
import 'lrclib_provider.dart';
import 'youlyplus_provider.dart';
import 'kugou_provider.dart';
import 'lyrics_registry.dart';
import 'apple_music_service.dart';
import 'audio_proxy.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register Dio with default timeouts
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  
  getIt.registerLazySingleton<Dio>(() => dio);
  
  // Register YoutubeAuthService
  final authService = YoutubeAuthService();
  getIt.registerSingleton<YoutubeAuthService>(authService);
  authService.init();

  // Register InnerTubeService
  getIt.registerLazySingleton<InnerTubeService>(() => InnerTubeService(getIt<Dio>(), getIt<YoutubeAuthService>()));

  // Register JioSaavnService
  getIt.registerLazySingleton<JioSaavnService>(() => JioSaavnService(getIt<Dio>()));

  // Register AppleMusicService
  getIt.registerLazySingleton<AppleMusicService>(() => AppleMusicService(getIt<Dio>()));

  // Register LyricsRegistry and its providers
  getIt.registerLazySingleton<LyricsRegistry>(() => LyricsRegistry([
    LrcLibProvider(getIt<Dio>()),
    YouLyPlusProvider(getIt<Dio>()),
    KuGouProvider(getIt<Dio>()),
  ]));

  // Register AudioProxy
  getIt.registerSingleton<AudioProxy>(AudioProxy());
}

