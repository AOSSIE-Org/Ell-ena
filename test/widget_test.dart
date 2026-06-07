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

  testWidgets('Spanish localization provides dashboard label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).dashboard),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panel'), findsOneWidget);
  });
}
