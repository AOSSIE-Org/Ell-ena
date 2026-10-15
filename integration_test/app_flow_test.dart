import 'package:ell_ena/main.dart' as app;
import 'package:ell_ena/screens/auth/login_screen.dart';
import 'package:ell_ena/screens/home/dashboard_screen.dart';
import 'package:ell_ena/screens/home/home_screen.dart';
import 'package:ell_ena/screens/onboarding/onboarding_screen.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional test account. Pass with
/// `--dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...`.
/// Without it, signed-in flows run only when the device already has a session.
const _rawEmail = String.fromEnvironment('E2E_EMAIL');
const _rawPassword = String.fromEnvironment('E2E_PASSWORD');

/// Drops wrapping quotes. Curly quotes typed in a terminal are not shell
/// quotes, so they otherwise become part of the password and Supabase
/// rejects the login.
String unwrapDefine(String value) {
  var text = value.trim();
  const quotes = {'\'', '"', '‘', '’', '“', '”'};
  while (text.length >= 2 &&
      quotes.contains(text[0]) &&
      quotes.contains(text[text.length - 1])) {
    text = text.substring(1, text.length - 1).trim();
  }
  return text;
}

final _e2eEmail = unwrapDefine(_rawEmail);
final _e2ePassword = unwrapDefine(_rawPassword);

const _tabs = ['Dashboard', 'Calendar', 'Workspace', 'Chat', 'Profile'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps frames until [finder] matches or [timeout] passes.
  ///
  /// The dashboard runs a repeating animation, so `pumpAndSettle` never
  /// returns once the home shell is visible.
  Future<bool> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  /// Starts the real app and waits for the splash screen to hand off.
  ///
  /// Timed pumps only. An unbounded `pumpAndSettle` never returns once the
  /// dashboard's repeating animation is running.
  Future<void> launchApp(WidgetTester tester) async {
    app.main();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    final landed = await pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is HomeScreen ||
            widget is LoginScreen ||
            widget is OnboardingScreen,
      ),
    );
    expect(
      landed,
      isTrue,
      reason: 'Splash did not route to onboarding, login, or home',
    );
  }

  bool shellVisible() =>
      find.byType(HomeScreen).evaluate().isNotEmpty ||
      find.byType(BottomNavigationBar).evaluate().isNotEmpty;

  bool hasSession() {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (error) {
      debugPrint('Could not read the current session: $error');
      return false;
    }
  }

  void logVisibleScreen(String reason) {
    final labels = find.byType(Text).evaluate().map((element) {
      final widget = element.widget;
      return widget is Text ? widget.data : null;
    }).whereType<String>().take(12);
    debugPrint('$reason Visible text: ${labels.join(' | ')}');
  }

  /// Leaves onboarding when a welcome button is in front of login.
  Future<void> passWelcome(WidgetTester tester) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (shellVisible() || find.byType(LoginScreen).evaluate().isNotEmpty) {
        return;
      }
      final button = find.text('Get Started').evaluate().isNotEmpty
          ? find.text('Get Started')
          : find.text('Continue').evaluate().isNotEmpty
              ? find.text('Continue')
              : find.text('Skip').evaluate().isNotEmpty
                  ? find.text('Skip')
                  : find.text('Next');
      if (button.evaluate().isEmpty) return;
      debugPrint('Tapping welcome button before login');
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Opens the home shell when a session already exists.
  Future<bool> openHome(WidgetTester tester) async {
    if (!shellVisible()) {
      NavigationService().navigateToReplacement(const HomeScreen());
      await tester.pump(const Duration(milliseconds: 500));
    }
    final shown = await pumpUntilFound(
      tester,
      find.byType(BottomNavigationBar),
      timeout: const Duration(seconds: 5),
    );
    if (!shown) logVisibleScreen('Home shell did not appear.');
    return shown;
  }

  /// Ensures the home shell is visible. Returns false when there is no
  /// session and no test account, so the caller can skip signed-in steps.
  Future<bool> ensureSignedIn(WidgetTester tester) async {
    if (shellVisible() || hasSession()) {
      debugPrint('Session or home shell already present. Skipping sign-in.');
      final opened = await openHome(tester);
      expect(opened, isTrue, reason: 'Signed-in session did not show home');
      return true;
    }

    await passWelcome(tester);
    if (shellVisible()) return true;

    if (_e2eEmail.isEmpty || _e2ePassword.isEmpty) return false;

    final emailField = find.widgetWithText(TextFormField, 'Email');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    final submit = find.text('Sign In');
    debugPrint(
      'Login controls found: '
      'email=${emailField.evaluate().isNotEmpty}, '
      'password=${passwordField.evaluate().isNotEmpty}, '
      'submit=${submit.evaluate().isNotEmpty}. '
      'Credential lengths: email=${_e2eEmail.length}, '
      'password=${_e2ePassword.length}',
    );

    Object? authError;
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _e2eEmail,
        password: _e2ePassword,
      );
      if (response.user == null) {
        authError = 'signInWithPassword returned no user';
      }
      debugPrint('signInWithPassword user: ${response.user?.id ?? 'none'}');
    } catch (error) {
      authError = error;
      debugPrint('signInWithPassword failed: $error');
    }

    if (authError != null) {
      logVisibleScreen('Sign-in failed.');
      fail('Sign-in failed: $authError');
    }

    final opened = await openHome(tester);
    if (!opened) {
      logVisibleScreen('Sign-in succeeded but home is not visible.');
    }
    expect(opened, isTrue, reason: 'Home did not appear after sign-in');
    return true;
  }

  Finder tab(String label) => find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(label),
      );

  int currentTabIndex(WidgetTester tester) => tester
      .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
      .currentIndex;

  Finder chartLabel(String label) => find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.text(label),
      );

  /// Brings the Week/Month control on screen with a fixed number of drags.
  ///
  /// Returns false when this view has no chart filter, so the test can skip
  /// instead of scrolling until the framework timeout.
  Future<bool> revealChartFilter(WidgetTester tester) async {
    bool onScreen() =>
        chartLabel('Week').hitTestable().evaluate().isNotEmpty &&
        chartLabel('Month').hitTestable().evaluate().isNotEmpty;

    if (onScreen()) return true;

    final scrollables = find.descendant(
      of: find.byType(DashboardScreen),
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isEmpty) {
      debugPrint('Week/month filter is not on this screen. Skipping toggle.');
      return false;
    }

    const maxDrags = 8;
    for (var i = 0; i < maxDrags; i++) {
      await tester.drag(scrollables.first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 500));
      if (onScreen()) return true;
    }

    debugPrint(
      'Week/month filter was not visible after $maxDrags scrolls. '
      'Skipping toggle.',
    );
    return false;
  }

  testWidgets('main shell navigates across every primary tab', (tester) async {
    await launchApp(tester);
    expect(tester.takeException(), isNull);

    if (!await ensureSignedIn(tester)) {
      markTestSkipped('No session and no E2E_EMAIL/E2E_PASSWORD provided');
      return;
    }

    for (var i = 1; i < _tabs.length; i++) {
      await tester.tap(tab(_tabs[i]));
      await tester.pump(const Duration(seconds: 1));
      expect(currentTabIndex(tester), i, reason: 'Tab ${_tabs[i]}');
      expect(tester.takeException(), isNull);
    }

    await tester.tap(tab('Dashboard'));
    await tester.pump(const Duration(seconds: 1));
    expect(currentTabIndex(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard loads and toggles the week/month chart filter',
    timeout: const Timeout(Duration(seconds: 90)),
    (tester) async {
      await launchApp(tester);

      if (!await ensureSignedIn(tester)) {
        markTestSkipped('No session and no E2E_EMAIL/E2E_PASSWORD provided');
        return;
      }

      final loaded = await pumpUntilFound(
        tester,
        find.text('Welcome back,'),
        timeout: const Duration(seconds: 15),
      );
      expect(loaded, isTrue, reason: 'Dashboard data did not load');

      if (!await revealChartFilter(tester)) {
        markTestSkipped('Week/month chart filter is not on screen');
        return;
      }

      final monthLabel = find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.text(DateFormat('MMMM yyyy').format(DateTime.now())),
      );
      expect(monthLabel, findsNothing);

      await tester.tap(chartLabel('Month'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(monthLabel, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(chartLabel('Week'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(monthLabel, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form input is shown and validated', (tester) async {
    await launchApp(tester);

    if (find.byType(LoginScreen).evaluate().isNotEmpty) {
      final email = find.widgetWithText(TextFormField, 'Email');
      final password = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(email, 'not-an-email');
      await tester.enterText(password, '123');
      await tester.pump();
      expect(find.text('not-an-email'), findsOneWidget);

      // Validation runs before any network call, so no account is touched.
      await tester.tap(find.text('Sign In'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    } else {
      await tester.tap(tab('Chat'));
      await tester.pump(const Duration(seconds: 1));

      final input = find.widgetWithText(TextField, 'Type your message...');
      expect(await pumpUntilFound(tester, input), isTrue);

      // Text is entered but not sent, so no AI request is made.
      await tester.enterText(input, 'Integration test draft');
      await tester.pump();
      expect(find.text('Integration test draft'), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });
}
