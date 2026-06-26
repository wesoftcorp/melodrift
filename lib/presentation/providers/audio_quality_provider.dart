import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_quality_preferences.dart';

final audioQualityProvider =
    StateNotifierProvider<AudioQualityNotifier, AudioQualitySettings>((ref) {
  return AudioQualityNotifier();
});

class AudioQualityNotifier extends StateNotifier<AudioQualitySettings> {
  AudioQualityNotifier() : super(const AudioQualitySettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await AudioQualityPreferences.load();
  }

  /// Updates and persists the preferred streaming quality.
  Future<void> setStreamingQuality(String quality) async {
    if (!streamingQualityOptions.contains(quality)) return;
    state = state.copyWith(streamingQuality: quality);
    await AudioQualityPreferences.setStreamingQuality(quality);
  }

  /// Updates and persists the preferred download quality.
  Future<void> setDownloadQuality(String quality) async {
    if (!downloadQualityOptions.contains(quality)) return;
    state = state.copyWith(downloadQuality: quality);
    await AudioQualityPreferences.setDownloadQuality(quality);
  }
}
