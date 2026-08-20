import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../data/datasources/local_music_source.dart';
import '../../data/models/local_models.dart';
import '../../flavors.dart';
import '../../core/utils/logger.dart';
import '../../presentation/providers/auth_provider.dart';

enum CloudSyncStatus { idle, syncing, synced, error }

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final localSource = ref.watch(localMusicSourceProvider);
  final authState = ref.watch(authProvider);
  final isFirebaseEnabled = ref.watch(firebaseEnabledProvider);
  return CloudSyncService(localSource, authState?.uid, isFirebaseEnabled);
});

final cloudSyncStatusProvider = StateProvider<CloudSyncStatus>((ref) => CloudSyncStatus.idle);
final lastSyncedTimeProvider = StateProvider<DateTime?>((ref) => null);

class CloudSyncService {
  final LocalMusicSource _localSource;
  final String? _uid;
  final bool _isFirebaseEnabled;
  final _log = AppLogger('CloudSyncService');

  CloudSyncService(this._localSource, this._uid, this._isFirebaseEnabled);

  /// Synchronize local playlists & history with Firebase Realtime Database
  Future<bool> syncNow(WidgetRef ref) async {
    if (_uid == null || !F.isFull || !_isFirebaseEnabled) {
      ref.read(cloudSyncStatusProvider.notifier).state = CloudSyncStatus.synced;
      ref.read(lastSyncedTimeProvider.notifier).state = DateTime.now();
      return true;
    }

    ref.read(cloudSyncStatusProvider.notifier).state = CloudSyncStatus.syncing;

    try {
      final dbRef = FirebaseDatabase.instance.ref('users/$_uid');

      // 1. Sync Playlists
      final localPlaylists = await _localSource.getAllPlaylists();
      final cloudPlaylistsSnapshot = await dbRef.child('playlists').get();

      if (cloudPlaylistsSnapshot.exists && cloudPlaylistsSnapshot.value is Map) {
        final cloudMap = cloudPlaylistsSnapshot.value as Map;
        for (final entry in cloudMap.entries) {
          final pMap = entry.value as Map;
          final playlistId = entry.key.toString();
          final existing = await _localSource.getPlaylist(playlistId);
          if (existing == null) {
            final p = LocalPlaylist()
              ..playlistId = playlistId
              ..title = pMap['title']?.toString() ?? 'Playlist'
              ..description = pMap['description']?.toString() ?? ''
              ..artworkUrl = pMap['artworkUrl']?.toString() ?? ''
              ..trackCount = (pMap['trackCount'] as int?) ?? 0
              ..isYouTube = (pMap['isYouTube'] as bool?) ?? false
              ..isLocal = (pMap['isLocal'] as bool?) ?? true;
            await _localSource.savePlaylist(p);
          }
        }
      }

      // Upload any local playlists to cloud
      for (final p in localPlaylists) {
        await dbRef.child('playlists/${p.playlistId}').set({
          'title': p.title,
          'description': p.description,
          'artworkUrl': p.artworkUrl,
          'trackCount': p.trackCount,
          'isYouTube': p.isYouTube,
          'isLocal': p.isLocal,
        });
      }

      // 2. Sync Listening History
      final localHistory = await _localSource.getListeningHistory();
      for (final h in localHistory.take(25)) {
        await dbRef.child('history/${h.songId}').set({
          'title': h.title,
          'artist': h.artist,
          'artworkUrl': h.artworkUrl,
          'playedAt': h.playedAt.toIso8601String(),
        });
      }

      ref.read(cloudSyncStatusProvider.notifier).state = CloudSyncStatus.synced;
      ref.read(lastSyncedTimeProvider.notifier).state = DateTime.now();
      _log.info('Cloud sync completed successfully for user: $_uid');
      return true;
    } catch (e) {
      _log.error('Cloud sync failed: $e');
      ref.read(cloudSyncStatusProvider.notifier).state = CloudSyncStatus.error;
      return false;
    }
  }
}
