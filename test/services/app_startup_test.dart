import 'dart:convert';

import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/services/app_startup.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  setUpAll(setUpFakeSupabase);

  test('finishes without Gemini so the rest of the app still works', () async {
    // Supabase is up (the harness started it); the Gemini key is missing.
    rootBundle.evict('.env');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      return key == '.env'
          ? ByteData.sublistView(utf8.encode('SUPABASE_URL=x\n'))
          : null;
    });
    expect(AppStartup.isReady, isFalse);

    await AppStartup.ensureInitialized();

    expect(AppStartup.isReady, isTrue);
    expect(SupabaseService().isInitialized, isTrue);
    expect(AIService().isInitialized, isFalse);
  });

  test('later calls share the finished run', () {
    expect(
      identical(AppStartup.ensureInitialized(), AppStartup.ensureInitialized()),
      isTrue,
    );
  });
}
