import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  testWidgets('steps through every slide and then goes to login',
      (tester) async {
    await pumpRoutedScreen(tester, const OnboardingScreen());

    expect(find.text(l10n.onboardingTaskManagementTitle), findsOneWidget);
    expect(find.text(l10n.onboardingNext), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingAssistantTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingContextTitle), findsOneWidget);
    expect(find.text(l10n.onboardingGetStarted), findsOneWidget);
    expect(find.text(l10n.onboardingNext), findsNothing);

    await tester.tap(find.text(l10n.onboardingGetStarted));
    await settle(tester);
    expect(find.text(loginPageText), findsOneWidget);
  });

  testWidgets('swiping changes the slide', (tester) async {
    await pumpRoutedScreen(tester, const OnboardingScreen(),
        themeMode: ThemeMode.dark);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingAssistantTitle), findsOneWidget);
  });

  testWidgets('skip goes straight to login', (tester) async {
    await pumpRoutedScreen(tester, const OnboardingScreen());

    await tester.tap(find.text(l10n.onboardingSkip));
    await settle(tester);
    expect(find.text(loginPageText), findsOneWidget);
  });
}
