import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'responsive_utils.dart';

/// Selects [mobile], [tablet], or [desktop] child based on available width.
///
/// Uses [LayoutBuilder] so it reacts to window resizes (web/desktop) without
/// requiring a full app rebuild.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        switch (ResponsiveUtils.deviceSizeForWidth(width)) {
          case DeviceSize.mobile:
            return mobile;
          case DeviceSize.tablet:
            return tablet ?? desktop;
          case DeviceSize.desktop:
            return desktop;
        }
      },
    );
  }
}
