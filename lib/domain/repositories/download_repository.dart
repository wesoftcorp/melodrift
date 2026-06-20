import '../entities/download_task.dart';
import '../entities/song.dart';

abstract class DownloadRepository {
  /// Start downloading a song
  Future<void> downloadSong(Song song, {String quality = 'High'});

  /// Pause a downloading task
  Future<void> pauseDownload(String songId);

  /// Resume a paused download task
  Future<void> resumeDownload(String songId);

  /// Cancel/abort a download task
  Future<void> cancelDownload(String songId);

  /// Retrieve all download tasks (past and active)
  Future<List<DownloadTask>> getDownloadTasks();

  /// Stream of active download tasks progress/status updates
  Stream<List<DownloadTask>> getDownloadTasksStream();

  /// Delete a downloaded song from disk and database
  Future<void> deleteDownload(String songId);
}
