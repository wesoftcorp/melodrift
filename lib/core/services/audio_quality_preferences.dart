import 'package:shared_preferences/shared_preferences.dart';

const streamingQualityOptions = ['High', 'Medium', 'Low'];
const downloadQualityOptions = ['High', 'Standard'];

class AudioQualitySettings {
  final String streamingQuality;
  final String downloadQuality;

  const AudioQualitySettings({
    this.streamingQuality = 'High',
    this.downloadQuality = 'High',
  });

  /// Returns a copy with updated quality values.
  AudioQualitySettings copyWith({
    String? streamingQuality,
    String? downloadQuality,
  }) {
    return AudioQualitySettings(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
    );
  }
}

class AudioQualityPreferences {
  static const _streamingQualityKey = 'audio_quality_streaming';
  static const _downloadQualityKey = 'audio_quality_download';

  /// Loads persisted audio quality settings, falling back to High quality.
  static Future<AudioQualitySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final streamingQuality = prefs.getString(_streamingQualityKey) ?? 'High';
    final downloadQuality = prefs.getString(_downloadQualityKey) ?? 'High';

    return AudioQualitySettings(
      streamingQuality: streamingQualityOptions.contains(streamingQuality)
          ? streamingQuality
          : 'High',
      downloadQuality: downloadQualityOptions.contains(downloadQuality)
          ? downloadQuality
          : 'High',
    );
  }

  /// Persists the selected streaming quality.
  static Future<void> setStreamingQuality(String quality) async {
    if (!streamingQualityOptions.contains(quality)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streamingQualityKey, quality);
  }

  /// Persists the selected download quality.
  static Future<void> setDownloadQuality(String quality) async {
    if (!downloadQualityOptions.contains(quality)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadQualityKey, quality);
  }
}
