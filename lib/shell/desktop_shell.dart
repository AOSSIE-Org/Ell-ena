import 'package:flutter/material.dart';

import 'shell_destination.dart';
import 'widgets/shell_navigation_rail.dart';

class DesktopShell extends StatelessWidget {
  final Widget child;
  final ShellDestination selectedDestination;
  final ValueChanged<ShellDestination>? onDestinationSelected;

  const DesktopShell({
    super.key,
    required this.child,
    this.selectedDestination = ShellDestination.dashboard,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellNavigationRail(
            selectedDestination: selectedDestination,
            onDestinationSelected: onDestinationSelected,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
