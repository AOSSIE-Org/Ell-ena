import 'package:ell_ena/models/chat_message.dart';
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/chat_controller.dart';
import 'package:ell_ena/providers/locale_provider.dart';
import 'package:ell_ena/providers/navigation/models/home_tab.dart';
import 'package:ell_ena/providers/shared_preferences_provider.dart';
import 'package:ell_ena/providers/theme_provider.dart';
import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/theme/app_theme_mode.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('startup-only providers', () {
    test('fail loudly when the app forgot to override them', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
          () => container.read(sharedPreferencesProvider), throwsA(anything));
      expect(() => container.read(themeControllerProvider), throwsA(anything));
    });
  });

  group('localeControllerProvider', () {
    Future<ProviderContainer> containerWith(Map<String, Object> values) async {
      final prefs = await prefsWith(values);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to English', () async {
      final container = await containerWith({});

      expect(container.read(localeControllerProvider), const Locale('en'));
    });

    test('restores a saved supported language', () async {
      final container = await containerWith({'app_locale': 'hi'});

      expect(container.read(localeControllerProvider), const Locale('hi'));
    });

    test('ignores unsupported or empty saved languages', () async {
      for (final code in ['fr', '']) {
        final container = await containerWith({'app_locale': code});
        expect(container.read(localeControllerProvider), const Locale('en'));
      }
    });

    test('setLocale switches and persists the language', () async {
      final container = await containerWith({});

      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('hi'));

      expect(container.read(localeControllerProvider), const Locale('hi'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'hi');
    });
  });

  group('ThemeController', () {
    test('maps each mode to Flutter and to dark-ness', () async {
      final controller = ThemeController(await prefsWith({}));
      final binding = TestWidgetsFlutterBinding.instance;
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

      await controller.setThemeMode(AppThemeMode.light);
      expect(controller.flutterThemeMode, ThemeMode.light);
      expect(controller.isDarkMode, isFalse);

      await controller.setThemeMode(AppThemeMode.dark);
      expect(controller.flutterThemeMode, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);

      await controller.setThemeMode(AppThemeMode.system);
      expect(controller.flutterThemeMode, ThemeMode.system);
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      expect(controller.isDarkMode, isTrue);
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      expect(controller.isDarkMode, isFalse);
    });

    test('setting the same mode does not notify or write', () async {
      final prefs = await prefsWith({'app_theme_mode': 'dark'});
      final controller = ThemeController(prefs);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setThemeMode(AppThemeMode.dark);
      await controller.setThemeMode(AppThemeMode.light);

      expect(notified, 1);
      expect(prefs.getString('app_theme_mode'), 'light');
    });

    test('create reads the saved mode', () async {
      await prefsWith({'app_theme_mode': 'light'});

      final controller = await ThemeController.create();

      expect(controller.themeMode, AppThemeMode.light);
    });
  });

  group('HomeTab.fromIndex', () {
    test('maps valid indexes and falls back to the dashboard', () {
      expect(HomeTab.values.map((t) => HomeTab.fromIndex(t.index)),
          HomeTab.values);
      expect(HomeTab.fromIndex(-1), HomeTab.dashboard);
      expect(HomeTab.fromIndex(HomeTab.values.length), HomeTab.dashboard);
    });
  });

  group('ChatController', () {
    late ProviderContainer container;
    late ChatController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(chatControllerProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('adds the welcome message only to an empty chat', () {
      controller.addWelcomeIfEmpty();
      controller.addWelcomeIfEmpty();

      final messages = container.read(chatControllerProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.single.isUser, isFalse);
      expect(messages.single.text, startsWith("Hello! I'm Ell-ena"));
    });

    test('appends messages and tracks processing and team members', () {
      final members = [
        {'id': 'u1', 'full_name': 'Ada'}
      ];
      controller.setTeamMembers(members);
      members.add({'id': 'u2'});
      controller.setProcessing(true);
      controller.addMessage(
          ChatMessage(text: 'hi', isUser: true, timestamp: DateTime(2026)));

      final state = container.read(chatControllerProvider);
      expect(state.teamMembers, hasLength(1));
      expect(state.isProcessing, isTrue);
      expect(state.messages.single.text, 'hi');

      controller.addWelcomeIfEmpty();
      expect(container.read(chatControllerProvider).messages, hasLength(1));
    });

    test('historyForAi keeps the latest turns before the pending question', () {
      for (var i = 0; i < 15; i++) {
        controller.addMessage(ChatMessage(
            text: 'm$i', isUser: i.isEven, timestamp: DateTime(2026)));
      }

      final history = controller.historyForAi(limit: 4);

      expect(history.map((h) => h['content']), ['m10', 'm11', 'm12', 'm13']);
      // m14 is the question being asked now, so it is left out.
      expect(history.first['role'], 'user');
      expect(history.last['role'], 'model');
    });

    test('the default retriever comes from the app AIService', () async {
      expect(container.read(aiServiceProvider), same(AIService()));

      final outcome =
          await container.read(ragRetrieverProvider).retrieve('   ');

      expect(outcome.status, RagRetrievalStatus.empty);
    });
  });
}
