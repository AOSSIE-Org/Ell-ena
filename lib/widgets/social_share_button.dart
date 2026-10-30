import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'social_share_host_stub.dart'
    if (dart.library.html) 'social_share_host_web.dart';

/// AOSSIE Social Share Button on the wide web layout.
///
/// Phone, Android, and iOS builds draw nothing.
class SocialShareSlot extends StatelessWidget {
  const SocialShareSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !AppShell.isDesktop(context)) {
      return const SizedBox.shrink();
    }
    final theme =
        Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: SizedBox(
          height: 48,
          width: 220,
          child: SocialShareHost(theme: theme),
        ),
      ),
    );
  }
}
