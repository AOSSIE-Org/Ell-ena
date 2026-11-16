import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ell_ena/l10n/app_localizations.dart';

void main() {
  testWidgets('English localization provides dashboard label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).dashboard),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Hindi localization provides dashboard label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).dashboard),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('डैशबोर्ड'), findsOneWidget);
  });

  testWidgets('languageName returns English for en locale code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(AppLocalizations.of(context).languageName('en')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('languageName returns Hindi for hi locale code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(AppLocalizations.of(context).languageName('hi')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('हिन्दी'), findsOneWidget);
  });

  test('supportedLocales includes English and Hindi', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const [Locale('en'), Locale('hi')]),
    );
  });
}
