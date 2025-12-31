import 'supported_language.dart';
import 'sentences.dart';
import 'english_sentences.dart';
import 'hindi_sentences.dart';
import 'package:get/get.dart';
import '../../controllers/language_controller.dart';

class SentenceManager {
  final SupportedLanguage currentLanguage;

  SentenceManager({required this.currentLanguage});

  Sentences get sentences {
    switch (currentLanguage) {
      case SupportedLanguage.hindi:
        return HindiSentences();
      case SupportedLanguage.english:
      default:
        return EnglishSentences();
    }
  }

  static Sentences get instance {
    try {
      final languageController = Get.find<LanguageController>();
      return SentenceManager(
              currentLanguage: languageController.selectedLanguage.value)
          .sentences;
    } catch (e) {
      // Fallback for when controller is not found (e.g. testing)
      return EnglishSentences();
    }
  }
}
