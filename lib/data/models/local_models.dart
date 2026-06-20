import 'package:isar/isar.dart';

part 'local_models.g.dart';

@collection
class LocalSong {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String songId;

  late String title;
  late String artist;
  late String album;
  late int durationMs;
  late String artworkUrl;
  late String videoId;
  String? filePath;
  late bool isDownloaded;
}

@collection
class LocalPlaylist {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String playlistId;

  late String title;
  late String description;
  late String artworkUrl;
  late int trackCount;
  late bool isYouTube;
  late bool isLocal;

  final songs = IsarLinks<LocalSong>();
}

enum LocalDownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

@collection
class DownloadRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String songId;

  late String title;
  late String artist;
  late String quality;
  late double progress;

  @enumerated
  late LocalDownloadStatus status;

  String? filePath;
  late DateTime createdAt;
}

@collection
class ListeningHistoryRecord {
  Id id = Isar.autoIncrement;

  late String songId;
  late String title;
  late String artist;
  late String artworkUrl;
  late DateTime playedAt;
}

@collection
class SearchHistoryRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String query;

  late DateTime searchedAt;
}
