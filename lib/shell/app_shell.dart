import 'package:flutter/material.dart';

import 'desktop_shell.dart';
import 'shell_destination.dart';

class AppShell extends StatelessWidget {
  /// Matches Figma desktop artboards (~1700px). Sidebar shell activates at
  /// this width; mobile bottom navigation remains below it.
  static const double desktopBreakpoint = 1024;

  final Widget mobile;
  final Widget child;
  final ShellDestination selectedDestination;
  final ValueChanged<ShellDestination>? onDestinationSelected;

  const AppShell({
    super.key,
    required this.mobile,
    required this.child,
    this.selectedDestination = ShellDestination.dashboard,
    this.onDestinationSelected,
  });

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return DesktopShell(
        selectedDestination: selectedDestination,
        onDestinationSelected: onDestinationSelected,
        child: child,
      );
    }

    return mobile;
  }
}
