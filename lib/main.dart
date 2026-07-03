import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui' as ui;

import 'app.dart';
import 'flavors.dart';
import 'firebase_options.dart';
import 'core/theme/theme_provider.dart';
import 'data/models/local_models.dart';
import 'data/datasources/local_music_source.dart';
import 'core/services/audio_handler.dart';
import 'core/utils/logger.dart';
import 'core/services/service_locator.dart';
import 'core/services/audio_proxy.dart';

final _log = AppLogger('main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  
  // Start local HTTP Audio Proxy in the background (non-blocking)
  unawaited(getIt<AudioProxy>().start().catchError((Object e, StackTrace s) {
    _log.error('Failed to start AudioProxy in background: $e', e, s);
  }));

  final flavorName = appFlavor?.toLowerCase() ?? 'prodfull';
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name.toLowerCase() == flavorName,
    orElse: () => Flavor.prodfull,
  );

  final prefs = await SharedPreferences.getInstance();

  // Reset home screen caches to force fresh API refetches for all sections
  final keys = prefs.getKeys();
  for (final key in keys) {
    if (key.startsWith('home_feed_cache_')) {
      await prefs.remove(key);
    }
  }

  // Initialize Firebase Core only if opted-in and on Full flavor
  final useFirebase = prefs.getBool('use_firebase') ?? false;
  if (F.isFull && useFirebase) {
    try {
      _log.info('Initializing Firebase for ${F.name} flavor...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Set up Crashlytics collection
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Pass uncaught exceptions to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

      // Pass isolate exceptions to Crashlytics
      ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
        FirebaseCrashlytics.instance
            .recordError(error, stackTrace as StackTrace?, fatal: true);
        return true;
      };

      await prefs.setBool('firebase_initialized', true);
      _log.info('Firebase initialized successfully with Crashlytics enabled');
    } catch (e, st) {
      _log.error(
        'Firebase initialization failed, running in offline mode. Reason: $e',
        e,
        st,
      );
      // Disable Firebase for this session so the app continues to work
      await prefs.setBool('firebase_initialized', false);
      await prefs.setBool('use_firebase', false);
      _log.warning('App will continue with offline/FOSS features only');
    }
  } else if (F.isFull) {
    _log.info('Firebase disabled in preferences. Using FOSS-compatible mode');
  } else {
    _log.info('Using ${F.name} flavor - Firebase not available');
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

  // Clean up failed/pending download records on startup to clear download failed cache state
  await isar.writeTxn(() async {
    await isar.downloadRecords
        .filter()
        .statusEqualTo(LocalDownloadStatus.failed)
        .or()
        .statusEqualTo(LocalDownloadStatus.pending)
        .or()
        .statusEqualTo(LocalDownloadStatus.downloading)
        .deleteAll();
  });

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
