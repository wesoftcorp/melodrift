enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

class DownloadTask {
  final String songId;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String quality;
  final DateTime createdAt;

  const DownloadTask({
    required this.songId,
    required this.status,
    required this.progress,
    required this.quality,
    required this.createdAt,
    this.filePath,
  });
}
