import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';

import 'app.dart';
import 'flavors.dart';
import 'core/theme/theme_provider.dart';
import 'data/models/local_models.dart';
import 'data/datasources/local_music_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
  );

  final prefs = await SharedPreferences.getInstance();

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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
      ],
      child: const App(),
    ),
  );
}
