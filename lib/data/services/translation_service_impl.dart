import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../../domain/services/translation_service.dart';

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationServiceImpl();
});

class TranslationServiceImpl implements TranslationService {
  final Map<String, String> _cache = {};
  final _modelManager = OnDeviceTranslatorModelManager();

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  TranslateLanguage _mapLanguage(String code) {
    return TranslateLanguage.values.firstWhere(
      (e) => e.bcpCode == code,
      orElse: () => TranslateLanguage.english,
    );
  }

  @override
  Future<bool> isModelDownloaded(String languageCode) async {
    if (_isDesktop) return true; // Mock models are always "downloaded"
    try {
      final lang = _mapLanguage(languageCode);
      return await _modelManager.isModelDownloaded(lang.bcpCode);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> downloadModel(String languageCode) async {
    if (_isDesktop) return;
    final lang = _mapLanguage(languageCode);
    await _modelManager.downloadModel(lang.bcpCode);
  }

  @override
  Future<String> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty) return '';

    final cacheKey = '$sourceLanguage-$targetLanguage-$text';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    if (_isDesktop) {
      // Premium Mock translation on Desktop
      final mockTranslated = _mockTranslate(text, targetLanguage);
      _cache[cacheKey] = mockTranslated;
      return mockTranslated;
    }

    try {
      final src = _mapLanguage(sourceLanguage);
      final tgt = _mapLanguage(targetLanguage);

      final translator = OnDeviceTranslator(sourceLanguage: src, targetLanguage: tgt);
      final result = await translator.translateText(text);
      await translator.close();

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      return '[Translation Error: $e]';
    }
  }

  String _mockTranslate(String text, String targetLang) {
    // Basic mock dictionary for common song lyric phrases
    final lower = text.toLowerCase();
    if (targetLang == 'es') {
      if (lower.contains('love')) return text.replaceAll(RegExp('love', caseSensitive: false), 'amor');
      if (lower.contains('never')) return text.replaceAll(RegExp('never', caseSensitive: false), 'nunca');
      if (lower.contains('give you up')) return text.replaceAll(RegExp('give you up', caseSensitive: false), 'dejarte');
      return '$text (es)';
    } else if (targetLang == 'fr') {
      if (lower.contains('love')) return text.replaceAll(RegExp('love', caseSensitive: false), 'amour');
      if (lower.contains('never')) return text.replaceAll(RegExp('never', caseSensitive: false), 'jamais');
      return '$text (fr)';
    }
    return '$text ($targetLang)';
  }
}
