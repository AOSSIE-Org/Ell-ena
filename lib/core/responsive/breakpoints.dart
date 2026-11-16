/// Centralized layout breakpoints for Ell-ena responsive layouts.
///
/// Widths are logical pixels (same as [MediaQuery.sizeOf] width).
class Breakpoints {
  Breakpoints._();
  /// Maximum width (exclusive) for [DeviceSize.mobile].
  static const double mobileMax = 600;

  /// Maximum width (exclusive) for [DeviceSize.tablet].
  static const double tabletMax = 1024;
}

/// Device size bucket derived from layout width.
enum DeviceSize {
  mobile,
  tablet,
  desktop,
}
