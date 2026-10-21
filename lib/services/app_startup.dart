import 'package:flutter/foundation.dart';

import 'ai_service.dart';
import 'supabase_service.dart';

/// Service setup that must finish before any screen touches Supabase.
///
/// Runs after the first frame so the splash is visible while it works. The
/// future is shared, so the splash and the route guard wait on the same run.
class AppStartup {
  AppStartup._();

  static Future<void>? _run;
  static bool _isReady = false;

  static bool get isReady => _isReady;

  /// Starts setup on first call; later calls return the same future. A failed
  /// run is cleared so the splash can retry.
  static Future<void> ensureInitialized() {
    return _run ??= _initialize().then(
      (_) => _isReady = true,
      onError: (Object error, StackTrace stackTrace) {
        _run = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  static Future<void> _initialize() async {
    await SupabaseService().initialize();
    // Chat degrades without Gemini, but the rest of the app still works.
    try {
      await AIService().initialize();
    } catch (e) {
      debugPrint('Error initializing AI service: $e');
    }
  }
}
