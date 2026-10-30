import 'package:ell_ena/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    Size size = phoneSize,
  }) {
    return pumpApp(
      tester,
      Scaffold(body: child),
      themeMode: themeMode,
      size: size,
    );
  }

  group('CustomTextField', () {
    testWidgets('uses label, icon, and password masking', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pump(
        tester,
        CustomTextField(
          controller: controller,
          label: 'Email',
          icon: Icons.email_outlined,
          isPassword: true,
          onChanged: changes.add,
          validator: (v) => (v ?? '').isEmpty ? 'required' : null,
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
          isTrue);

      await tester.enterText(find.byType(TextFormField), 'ada');
      expect(changes, ['ada']);
      expect(controller.text, 'ada');
    });

    testWidgets('falls back to hint, prefix icon, and obscureText',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        CustomTextField(
          controller: controller,
          hintText: 'Search',
          prefixIcon: Icons.search,
          obscureText: true,
          enabled: false,
          keyboardType: TextInputType.number,
        ),
      );

      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
      expect(editable.keyboardType, TextInputType.number);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('has no prefix icon when none is given', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(tester, CustomTextField(controller: controller));

      expect(find.byType(Icon), findsNothing);
    });
  });

  group('CustomButton', () {
    testWidgets('filled button calls back with its text', (tester) async {
      var taps = 0;
      await pump(tester, CustomButton(text: 'Go', onPressed: () => taps++));

      await tester.tap(find.text('Go'));
      expect(taps, 1);
      final style = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(style.style!.backgroundColor!.resolve({}), Colors.green.shade400);
    });

    testWidgets('outlined button is transparent with a green border',
        (tester) async {
      await pump(
        tester,
        CustomButton(text: 'Back', onPressed: () {}, isOutlined: true),
        themeMode: ThemeMode.dark,
      );

      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
      final shape = style.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.side.color, Colors.green.shade400);
    });

    testWidgets('loading replaces the text with a spinner', (tester) async {
      await pump(
        tester,
        const CustomButton(text: 'Save', onPressed: null, isLoading: true),
      );

      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });

  group('AuthScreenWrapper', () {
    testWidgets('keeps the phone layout on wide screens unless asked',
        (tester) async {
      await pumpApp(
        tester,
        const AuthScreenWrapper(
          title: 'Verify',
          subtitle: 'Check your inbox',
          children: [Text('form')],
        ),
        size: wideSize,
      );

      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('form'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 480),
        findsNothing,
      );
    });

    testWidgets('centres the form in a card when asked on wide screens',
        (tester) async {
      await pumpApp(
        tester,
        const AuthScreenWrapper(
          title: 'Welcome',
          subtitle: 'Sign in',
          centerOnWideScreens: true,
          children: [Text('form')],
        ),
        size: wideSize,
      );

      final card = find.ancestor(
        of: find.text('form'),
        matching: find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 480),
      );
      expect(card, findsOneWidget);
      final centre = tester.getCenter(find.text('Welcome'));
      expect(centre.dx, greaterThan(wideSize.width / 3));
    });

    testWidgets('a phone ignores the wide-screen flag', (tester) async {
      await pumpApp(
        tester,
        const AuthScreenWrapper(
          title: 'Welcome',
          subtitle: 'Sign in',
          centerOnWideScreens: true,
          children: [Text('form')],
        ),
      );

      expect(
        find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 480),
        findsNothing,
      );
      expect(find.text('form'), findsOneWidget);
    });
  });

  testWidgets('CustomLoading passes its size and colour to the animation',
      (tester) async {
    await pump(tester, const CustomLoading(size: 24, color: Colors.red));

    // The package does not export the animation widget's type.
    final dots = tester.widget(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'StretchedDots')) as dynamic;
    expect(dots.size, 24);
    expect(dots.color, Colors.red);
  });

  group('loading skeletons', () {
    // Keyed rather than const, so each test builds a fresh instance.
    final skeletons = <String, Widget Function()>{
      'dashboard': () => DashboardLoadingSkeleton(key: UniqueKey()),
      'calendar': () => CalendarLoadingSkeleton(key: UniqueKey()),
    };

    // Skeletonizer's constructor builds a private subclass.
    final skeletonizer = find.byWidgetPredicate((w) => w is Skeletonizer);

    ShimmerEffect effect(WidgetTester tester) =>
        tester.widget<Skeletonizer>(skeletonizer).effect! as ShimmerEffect;

    skeletons.forEach((name, skeleton) {
      testWidgets('$name skeleton shimmers in light colours', (tester) async {
        await pump(tester, skeleton());

        expect(tester.widget<Skeletonizer>(skeletonizer).enabled, isTrue);
        // Base, highlight, base.
        expect(effect(tester).colors,
            const [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$name skeleton shimmers in dark colours', (tester) async {
        await pump(tester, skeleton(), themeMode: ThemeMode.dark);

        expect(effect(tester).colors,
            const [Color(0xFF2D2D2D), Color(0xFF3D3D3D), Color(0xFF2D2D2D)]);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
