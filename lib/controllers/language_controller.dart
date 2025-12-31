import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language/supported_language.dart';

class LanguageController extends GetxController {
  static const String _storageKey = 'selected_language';

  // Reactive variable observing the selected language
  Rx<SupportedLanguage> selectedLanguage = SupportedLanguage.english.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLangIndex = prefs.getInt(_storageKey);

    if (savedLangIndex != null &&
        savedLangIndex >= 0 &&
        savedLangIndex < SupportedLanguage.values.length) {
      selectedLanguage.value = SupportedLanguage.values[savedLangIndex];
    }
  }

  Future<void> setSelectedLanguage(SupportedLanguage language) async {
    // 1. Save to shared preferences (persistence)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, language.index);

    // 2. Update the reactive variable
    // This triggers all Obx() widgets to rebuild instantly
    selectedLanguage.value = language;
  }
}
