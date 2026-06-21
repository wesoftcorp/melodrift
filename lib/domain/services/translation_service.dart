abstract class TranslationService {
  /// Translates a single line of text from source to target language.
  Future<String> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Checks if the ML Kit translation model is downloaded for the given language.
  Future<bool> isModelDownloaded(String languageCode);

  /// Downloads the ML Kit translation model for the given language.
  Future<void> downloadModel(String languageCode);
}
