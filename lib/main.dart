import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'flavors.dart';
import 'firebase_options.dart';
import 'core/theme/theme_provider.dart';
import 'data/models/local_models.dart';
import 'data/datasources/local_music_source.dart';
import 'core/services/audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
  );

  final prefs = await SharedPreferences.getInstance();

  // Initialize Firebase Core only if opted-in and on Full flavor
  final useFirebase = prefs.getBool('use_firebase') ?? false;
  if (F.isFull && useFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      LocalSongSchema,
      LocalPlaylistSchema,
      DownloadRecordSchema,
      ListeningHistoryRecordSchema,
      SearchHistoryRecordSchema,
    ],
    directory: dir.path,
  );

  // Initialize the Background Audio Service
  final audioHandler = await AudioService.init(
    builder: () => MelodriftAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.melodrift.channel.audio',
      androidNotificationChannelName: 'Melodrift Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const App(),
    ),
  );
}
