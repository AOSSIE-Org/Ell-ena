import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'support_us_host_stub.dart'
    if (dart.library.html) 'support_us_host_web.dart';

/// Opens the AOSSIE support panel. Phone, Android, and iOS do nothing.
void openSupportUs(BuildContext context) {
  if (!kIsWeb) return;
  final theme =
      Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
  showSupportOverlay(theme);
}
