import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/l10n/app_localizations_en.dart';
import 'package:ell_ena/l10n/app_localizations_hi.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations hi = AppLocalizationsHi();

  test('labels match the localised page names', () {
    expect(
      {for (final d in ShellDestination.values) d: d.labelFor(en)},
      {
        ShellDestination.dashboard: 'Dashboard',
        ShellDestination.calendar: 'Calendar',
        ShellDestination.tasks: 'Tasks',
        ShellDestination.tickets: 'Tickets',
        ShellDestination.meetings: 'Meetings',
        ShellDestination.chat: 'Chat',
        ShellDestination.profile: 'Profile',
      },
    );
  });

  test('every label is translated to Hindi', () {
    for (final destination in ShellDestination.values) {
      expect(
        destination.labelFor(hi),
        isNot(destination.labelFor(en)),
        reason: destination.name,
      );
    }
  });

  test('each destination has distinct icons, filled when selected', () {
    final icons = ShellDestination.values.map((d) => d.icon).toSet();
    final selected = ShellDestination.values.map((d) => d.selectedIcon).toSet();

    expect(icons, hasLength(ShellDestination.values.length));
    expect(selected, hasLength(ShellDestination.values.length));
    for (final destination in ShellDestination.values) {
      expect(destination.icon, isNot(destination.selectedIcon));
    }
  });
}
