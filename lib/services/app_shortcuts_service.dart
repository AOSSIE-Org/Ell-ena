import 'package:flutter/services.dart';

class AppShortcutsService {
  AppShortcutsService._();

  static const MethodChannel _channel = MethodChannel('app_shortcuts');
  static String? _pendingShortcut;
  static Function(String route)? _onShortcutPressed;

  /// Initialize the shortcuts service and get initial shortcut if any
  static Future<void> initialize() async {
    try {
      // Get initial shortcut when app launches
      final initialRoute = await _channel.invokeMethod<String>('getInitialRoute');
      if (initialRoute != null && initialRoute.isNotEmpty) {
        _pendingShortcut = initialRoute;
      }
    } catch (e) {
      print('Error initializing shortcuts service: $e');
    }
  }

  /// Get and clear pending shortcut (for initial app launch)
  static String? getPendingShortcut() {
    final shortcut = _pendingShortcut;
    _pendingShortcut = null;
    return shortcut;
  }

  /// Initialize shortcut handler for in-app navigation
  static void init(void Function(String route) onShortcutPressed) {
    _onShortcutPressed = onShortcutPressed;
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final String route = call.arguments?.toString() ?? '';
        if (route.isNotEmpty) {
          _handleShortcut(route);
        }
      }
      return null;
    });
  }

  /// Handle shortcut route and convert to index for backward compatibility
  static void initWithIndex(void Function(int index) changeTab) {
    init((route) {
      int index = _routeToIndex(route);
      changeTab(index);
    });
  }

  /// Convert route string to tab index
  static int _routeToIndex(String route) {
    switch (route) {
      case 'dashboard': return 0;
      case 'calendar': return 1;
      case 'workspace': return 2;
      case 'chat': return 3;
      case 'profile': return 4;
      default: return 0;
    }
  }

  /// Convert tab index to route string
  static String _indexToRoute(int index) {
    switch (index) {
      case 0: return 'dashboard';
      case 1: return 'calendar';
      case 2: return 'workspace';
      case 3: return 'chat';
      case 4: return 'profile';
      default: return 'dashboard';
    }
  }

  /// Handle shortcut internally
  static void _handleShortcut(String route) {
    if (_onShortcutPressed != null) {
      _onShortcutPressed!(route);
    }
  }

  /// Manually trigger navigation (for testing or programmatic navigation)
  static void navigateTo(String route) {
    _handleShortcut(route);
  }

  /// Navigate to specific tab index
  static void navigateToIndex(int index) {
    final route = _indexToRoute(index);
    _handleShortcut(route);
  }

  /// Check if there's a pending shortcut
  static bool hasPendingShortcut() {
    return _pendingShortcut != null && _pendingShortcut!.isNotEmpty;
  }

  /// Clear any pending shortcuts
  static void clearPendingShortcut() {
    _pendingShortcut = null;
  }

  /// Send a shortcut to native (for testing or cross-platform communication)
  static Future<void> sendShortcutToNative(String route) async {
    try {
      await _channel.invokeMethod('navigate', route);
    } catch (e) {
      print('Error sending shortcut to native: $e');
    }
  }
}