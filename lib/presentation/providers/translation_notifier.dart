import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lyrics.dart';
import '../../domain/services/translation_service.dart';
import '../../data/services/translation_service_impl.dart';

class TranslationState {
  final bool isTranslating;
  final bool isModelDownloading;
  final String targetLanguage;
  final Map<int, String> translatedLines;
  final String? error;

  const TranslationState({
    required this.isTranslating,
    required this.isModelDownloading,
    required this.targetLanguage,
    required this.translatedLines,
    this.error,
  });

  TranslationState copyWith({
    bool? isTranslating,
    bool? isModelDownloading,
    String? targetLanguage,
    Map<int, String>? translatedLines,
    String? error,
  }) {
    return TranslationState(
      isTranslating: isTranslating ?? this.isTranslating,
      isModelDownloading: isModelDownloading ?? this.isModelDownloading,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translatedLines: translatedLines ?? this.translatedLines,
      error: error ?? this.error,
    );
  }
}

final translationProvider =
    StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  final service = ref.watch(translationServiceProvider);
  return TranslationNotifier(service);
});

class TranslationNotifier extends StateNotifier<TranslationState> {
  final TranslationService _service;

  TranslationNotifier(this._service)
      : super(const TranslationState(
          isTranslating: false,
          isModelDownloading: false,
          targetLanguage: 'en',
          translatedLines: {},
        ));

  void toggleTranslation(bool enabled, List<LyricLine> lines) {
    state = state.copyWith(isTranslating: enabled);
    if (enabled && state.translatedLines.isEmpty) {
      _translateAll(lines);
    }
  }

  void setTargetLanguage(String langCode, List<LyricLine> lines) {
    if (state.targetLanguage == langCode && state.translatedLines.isNotEmpty) return;
    state = state.copyWith(
      targetLanguage: langCode,
      translatedLines: {},
    );
    if (state.isTranslating) {
      _translateAll(lines);
    }
  }

  Future<void> _translateAll(List<LyricLine> lines) async {
    final lang = state.targetLanguage;
    state = state.copyWith(isModelDownloading: true, error: null);

    try {
      final isReady = await _service.isModelDownloaded(lang);
      if (!isReady) {
        await _service.downloadModel(lang);
      }
      state = state.copyWith(isModelDownloading: false);
    } catch (e) {
      state = state.copyWith(
        isModelDownloading: false,
        error: 'Failed to download translation model: $e',
      );
      return;
    }

    final newTranslations = Map<int, String>.from(state.translatedLines);
    
    // Perform translations sequentially to avoid overloading ML Kit
    for (final line in lines) {
      if (state.targetLanguage != lang || !state.isTranslating) break;
      if (line.text.trim().isEmpty) continue;

      try {
        final isDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(line.text);
        final sourceLang = isDevanagari ? 'hi' : (lang == 'hi' ? 'en' : 'en');

        final translated = await _service.translateText(
          text: line.text,
          sourceLanguage: sourceLang,
          targetLanguage: lang,
        );
        newTranslations[line.timeMs] = translated;
        state = state.copyWith(translatedLines: newTranslations);
      } catch (_) {
        // Ignore single line errors
      }
    }
  }
}
