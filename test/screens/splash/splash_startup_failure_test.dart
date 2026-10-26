import 'package:ell_ena/screens/onboarding/onboarding_screen.dart';
import 'package:ell_ena/screens/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

/// Its own file: [NavigationService] keeps its router for the whole isolate,
/// and this test needs it never to have been set.
void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  testWidgets('shows onboarding when the router is not ready', (tester) async {
    await pumpApp(tester, const SplashScreen());
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester);
    // Lets the route transition finish.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
