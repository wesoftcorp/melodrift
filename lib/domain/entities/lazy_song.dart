/// Lazy-loaded song data model to reduce memory footprint
/// 
/// Only essential fields are always loaded:
/// - id, title, artist, album (required for UI)
/// - videoId (required for streaming)
/// 
/// Optional fields are loaded on-demand:
/// - artworkUrl (loaded when displaying artwork)
/// - duration (cached after first playback)
/// - streamUrl (resolved only when playing)
class LazySong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String videoId;
  
  // Lazy-loaded fields
  String? _artworkUrl;
  Duration? _duration;
  String? _streamUrl;
  
  // Track if fields have been explicitly loaded
  bool _artworkLoaded = false;
  bool _durationLoaded = false;

  LazySong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.videoId,
    String? artworkUrl,
    Duration? duration,
    String? streamUrl,
  })  : _artworkUrl = artworkUrl,
        _duration = duration,
        _streamUrl = streamUrl,
        _artworkLoaded = artworkUrl != null,
        _durationLoaded = duration != null;

  /// Get artwork URL (lazy-load if needed)
  String get artworkUrl => _artworkUrl ?? '';
  
  /// Set artwork URL (e.g., after fetching from API)
  void setArtworkUrl(String url) {
    _artworkUrl = url;
    _artworkLoaded = true;
  }

  /// Get duration (lazy-load if needed)
  Duration get duration => _duration ?? Duration.zero;
  
  /// Set duration (e.g., after playback resolution)
  void setDuration(Duration dur) {
    _duration = dur;
    _durationLoaded = true;
  }

  /// Get stream URL (lazy-load if needed)
  String? get streamUrl => _streamUrl;
  
  /// Set stream URL (e.g., after YouTube API resolution)
  void setStreamUrl(String url) {
    _streamUrl = url;
  }

  /// Check if artwork is loaded
  bool get isArtworkLoaded => _artworkLoaded;
  
  /// Check if duration is loaded
  bool get isDurationLoaded => _durationLoaded;

  /// Get memory footprint estimate (bytes)
  int getMemoryFootprint() {
    int size = 0;
    size += 16; // id (UUID length average)
    size += title.length * 2; // UTF-16
    size += artist.length * 2;
    size += album.length * 2;
    size += videoId.length * 2;
    size += (_artworkUrl?.length ?? 0) * 2;
    size += (_streamUrl?.length ?? 0) * 2;
    size += 16; // Duration object
    return size;
  }

  /// Create a copy with optional field updates
  LazySong copyWith({
    String? artworkUrl,
    Duration? duration,
    String? streamUrl,
  }) {
    return LazySong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      videoId: videoId,
      artworkUrl: artworkUrl ?? _artworkUrl,
      duration: duration ?? _duration,
      streamUrl: streamUrl ?? _streamUrl,
    );
  }

  @override
  String toString() => 'LazySong(id: $id, title: $title, artist: $artist)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LazySong &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          videoId == other.videoId;

  @override
  int get hashCode => id.hashCode ^ videoId.hashCode;
}

