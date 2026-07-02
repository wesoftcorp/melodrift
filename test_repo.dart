import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/core/services/service_locator.dart';
import 'lib/data/repositories/music_repository_impl.dart';
import 'lib/data/datasources/youtube_music_remote_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setupServiceLocator();
  final repo = MusicRepositoryImpl(getIt<YouTubeMusicRemoteSource>());
  final url = await repo.getStreamUrl('jiosaavn_glfUm7JM');
  print('RESOLVED URL: $url');
}
