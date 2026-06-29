import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/download_task.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/download_repository.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/audio_quality_preferences.dart';
import '../datasources/local_music_source.dart';
import '../datasources/youtube_music_remote_source.dart';
import '../models/local_models.dart';
import 'lyrics_repository_impl.dart'; // import dioProvider

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final localSource = ref.watch(localMusicSourceProvider);
  final remoteSource = ref.watch(youtubeMusicRemoteSourceProvider);
  final dio = ref.watch(dioProvider);
  final downloadManager = ref.watch(downloadManagerProvider);
  return DownloadRepositoryImpl(
    localSource,
    remoteSource,
    dio,
    downloadManager,
  );
});

final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return repository.getDownloadTasksStream();
});

class DownloadRepositoryImpl implements DownloadRepository {
  final LocalMusicSource _localSource;
  final YouTubeMusicRemoteSource _remoteSource;
  final Dio _dio;
  final DownloadManager _downloadManager;

  // Track active downloads for cancellation
  final Map<String, CancelToken> _activeDownloads = {};

  DownloadRepositoryImpl(
    this._localSource,
    this._remoteSource,
    this._dio,
    this._downloadManager,
  );

  DownloadStatus _mapLocalStatus(LocalDownloadStatus local) {
    switch (local) {
      case LocalDownloadStatus.pending: return DownloadStatus.pending;
      case LocalDownloadStatus.downloading: return DownloadStatus.downloading;
      case LocalDownloadStatus.completed: return DownloadStatus.completed;
      case LocalDownloadStatus.failed: return DownloadStatus.failed;
      case LocalDownloadStatus.paused: return DownloadStatus.paused;
    }
  }

  DownloadTask _mapRecordToTask(DownloadRecord record) {
    return DownloadTask(
      songId: record.songId,
      status: _mapLocalStatus(record.status),
      progress: record.progress,
      filePath: record.filePath,
      quality: record.quality,
      createdAt: record.createdAt,
    );
  }

  @override
  Future<void> downloadSong(Song song, {String quality = 'High'}) async {
    // Wi-Fi Only Check
    final prefs = await SharedPreferences.getInstance();
    final downloadOnlyWifi = prefs.getBool('download_only_wifi') ?? false;
    if (downloadOnlyWifi) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.wifi &&
          connectivityResult != ConnectivityResult.ethernet &&
          connectivityResult != ConnectivityResult.vpn) {
        throw Exception('Wi-Fi Only downloads active. Connect to Wi-Fi to start.');
      }
    }

    final selectedQuality = quality == 'High'
        ? (await AudioQualityPreferences.load()).downloadQuality
        : quality;
    final existing = await _localSource.getDownloadRecord(song.id);
    if (existing != null && existing.status == LocalDownloadStatus.completed) {
      return;
    }

    final record = DownloadRecord()
      ..songId = song.id
      ..title = song.title
      ..artist = song.artist
      ..quality = selectedQuality
      ..progress = 0.0
      ..status = LocalDownloadStatus.pending
      ..createdAt = DateTime.now();

    await _localSource.saveDownloadRecord(record);

    // Trigger async download in background
    unawaited(_startDownloadProcess(song, selectedQuality));
  }

  Future<void> _startDownloadProcess(Song song, String quality) async {
    final record = await _localSource.getDownloadRecord(song.id);
    if (record == null) return;

    const maxAttempts = 3;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      final cancelToken = CancelToken();
      _activeDownloads[song.id] = cancelToken;

      try {
        record.status = LocalDownloadStatus.downloading;
        await _localSource.saveDownloadRecord(record);

        // Resolve Audio Stream URL — enforce timeout so a hung YouTube API call
        // doesn't silently stall the download task forever.
        final streamUrl = await _remoteSource
            .getStreamUrl(song.videoId, quality)
            .timeout(const Duration(seconds: 20));

        final tempDir = await getTemporaryDirectory();
        final cleanTitle = song.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
        final tempFile = File(p.join(tempDir.path, '${song.id}_$cleanTitle.download'));

        // Perform download to a temporary file before app-only storage.
        await _dio.download(
          streamUrl,
          tempFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) async {
            if (total != -1) {
              final progress = received / total;
              // Throttle database writes
              final currentProgressPercent = (progress * 100).round() / 100;
              if (currentProgressPercent - record.progress >= 0.02 || progress == 1.0) {
                record.progress = currentProgressPercent;
                await _localSource.saveDownloadRecord(record);
              }
            }
          },
        );

        final storedPath = await _downloadManager.storeDownloadedFile(
          songId: song.id,
          title: song.title,
          tempFile: tempFile,
        );

        record.status = LocalDownloadStatus.completed;
        record.filePath = storedPath;
        record.progress = 1.0;
        await _localSource.saveDownloadRecord(record);

        final localSong = LocalSong()
          ..songId = song.id
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..durationMs = song.duration.inMilliseconds
          ..artworkUrl = song.artworkUrl
          ..videoId = song.videoId
          ..filePath = storedPath
          ..isDownloaded = true;
        await _localSource.saveSong(localSong);

        // Success — exit retry loop.
        _activeDownloads.remove(song.id);
        return;

      } catch (e) {
        _activeDownloads.remove(song.id);

        if (e is DioException && CancelToken.isCancel(e)) {
          // User explicitly paused/cancelled — don't retry.
          record.status = LocalDownloadStatus.paused;
          await _localSource.saveDownloadRecord(record);
          return;
        }

        if (attempt >= maxAttempts) {
          record.status = LocalDownloadStatus.failed;
          record.progress = 0.0;
          await _localSource.saveDownloadRecord(record);
          return;
        }

        // Wait briefly before retrying (exponential backoff: 2s, 4s).
        await Future<void>.delayed(Duration(seconds: attempt * 2));
        record.progress = 0.0;
      }
    }
  }

  @override
  Future<void> pauseDownload(String songId) async {
    final token = _activeDownloads[songId];
    if (token != null) {
      token.cancel('Paused by user');
    }
    final record = await _localSource.getDownloadRecord(songId);
    if (record != null) {
      record.status = LocalDownloadStatus.paused;
      await _localSource.saveDownloadRecord(record);
    }
  }

  @override
  Future<void> resumeDownload(String songId) async {
    final record = await _localSource.getDownloadRecord(songId);
    if (record == null) return;

    final song = Song(
      id: record.songId,
      title: record.title,
      artist: record.artist,
      album: 'Single',
      duration: Duration.zero,
      artworkUrl: '',
      videoId: record.songId,
    );

    record.status = LocalDownloadStatus.pending;
    await _localSource.saveDownloadRecord(record);
    unawaited(_startDownloadProcess(song, record.quality));
  }

  @override
  Future<void> cancelDownload(String songId) async {
    final token = _activeDownloads[songId];
    if (token != null) {
      token.cancel('Cancelled by user');
    }
    await deleteDownload(songId);
  }

  @override
  Future<List<DownloadTask>> getDownloadTasks() async {
    final records = await _localSource.getAllDownloadRecords();
    return records.map(_mapRecordToTask).toList();
  }

  @override
  Stream<List<DownloadTask>> getDownloadTasksStream() {
    return _localSource.watchDownloadRecords().map(
          (records) => records.map(_mapRecordToTask).toList(),
        );
  }

  @override
  Future<void> deleteDownload(String songId) async {
    final record = await _localSource.getDownloadRecord(songId);
    if (record != null) {
      if (record.filePath != null) {
        final file = File(record.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await _localSource.deleteDownloadRecord(songId);
    }

    final localSong = await _localSource.getSong(songId);
    if (localSong != null) {
      localSong.isDownloaded = false;
      localSong.filePath = null;
      await _localSource.saveSong(localSong);
    }
  }
}
