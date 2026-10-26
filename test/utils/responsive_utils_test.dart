import 'package:ell_ena/core/responsive/breakpoints.dart';
import 'package:ell_ena/core/responsive/responsive_utils.dart';
import 'package:ell_ena/router/app_route_observer.dart';
import 'package:ell_ena/utils/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deviceSizeForWidth', () {
    test('splits widths at the breakpoints, upper bound exclusive', () {
      expect(ResponsiveUtils.deviceSizeForWidth(0), DeviceSize.mobile);
      expect(ResponsiveUtils.deviceSizeForWidth(Breakpoints.mobileMax - 0.1),
          DeviceSize.mobile);
      expect(ResponsiveUtils.deviceSizeForWidth(Breakpoints.mobileMax),
          DeviceSize.tablet);
      expect(ResponsiveUtils.deviceSizeForWidth(Breakpoints.tabletMax - 0.1),
          DeviceSize.tablet);
      expect(ResponsiveUtils.deviceSizeForWidth(Breakpoints.tabletMax),
          DeviceSize.desktop);
    });

    test('width helpers agree with the bucket', () {
      for (final width in [320.0, 600.0, 800.0, 1024.0, 1920.0]) {
        final size = ResponsiveUtils.deviceSizeForWidth(width);
        expect(ResponsiveUtils.isMobileWidth(width), size == DeviceSize.mobile);
        expect(ResponsiveUtils.isTabletWidth(width), size == DeviceSize.tablet);
        expect(
            ResponsiveUtils.isDesktopWidth(width), size == DeviceSize.desktop);
      }
    });
  });

  group('context helpers', () {
    Future<BuildContext> contextAt(WidgetTester tester, double width) async {
      late BuildContext captured;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ));
      return captured;
    }

    testWidgets('read the width from MediaQuery', (tester) async {
      final phone = await contextAt(tester, 390);
      expect(phone.deviceSize, DeviceSize.mobile);
      expect(phone.isMobile, isTrue);
      expect(phone.isTablet, isFalse);
      expect(phone.isDesktop, isFalse);

      final tablet = await contextAt(tester, 800);
      expect(ResponsiveUtils.deviceSizeOf(tablet), DeviceSize.tablet);
      expect(tablet.isTablet, isTrue);

      final desktop = await contextAt(tester, 1280);
      expect(ResponsiveUtils.isDesktop(desktop), isTrue);
      expect(ResponsiveUtils.isMobile(desktop), isFalse);
      expect(ResponsiveUtils.isTablet(desktop), isFalse);
    });
  });

  test('the route observer is a single shared instance', () {
    expect(AppRouteObserver.instance, same(AppRouteObserver.instance));
    expect(AppRouteObserver.instance, isA<RouteObserver<ModalRoute<void>>>());
  });

  test('the URL strategy is a no-op off the web', () {
    expect(configureAppUrlStrategy, returnsNormally);
  });
}
