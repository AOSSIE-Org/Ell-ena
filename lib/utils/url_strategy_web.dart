import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Configures path-based URLs on web; no-op on other platforms.
void configureAppUrlStrategy() {
  usePathUrlStrategy();
}
