import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Layout helpers based on screen width.
class ResponsiveUtils {
  ResponsiveUtils._();
  static DeviceSize deviceSizeForWidth(double width) {
    if (width < Breakpoints.mobileMax) return DeviceSize.mobile;
    if (width < Breakpoints.tabletMax) return DeviceSize.tablet;
    return DeviceSize.desktop;
  }

  static DeviceSize deviceSizeOf(BuildContext context) {
    return deviceSizeForWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isMobile(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.mobile;

  static bool isTablet(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.tablet;

  static bool isDesktop(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.desktop;

  static bool isMobileWidth(double width) =>
      deviceSizeForWidth(width) == DeviceSize.mobile;

  static bool isTabletWidth(double width) =>
      deviceSizeForWidth(width) == DeviceSize.tablet;

  static bool isDesktopWidth(double width) =>
      deviceSizeForWidth(width) == DeviceSize.desktop;
}

/// Convenience extensions on [BuildContext] for responsive checks.
extension ResponsiveContext on BuildContext {
  DeviceSize get deviceSize => ResponsiveUtils.deviceSizeOf(this);

  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
}
