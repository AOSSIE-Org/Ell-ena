import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum ShellDestination {
  dashboard,
  calendar,
  workspace,
  chat,
  profile;

  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case ShellDestination.dashboard:
        return l10n.dashboard;
      case ShellDestination.calendar:
        return l10n.calendar;
      case ShellDestination.workspace:
        return l10n.workspace;
      case ShellDestination.chat:
        return l10n.chat;
      case ShellDestination.profile:
        return l10n.profile;
    }
  }

  IconData get icon {
    switch (this) {
      case ShellDestination.dashboard:
        return Icons.dashboard_outlined;
      case ShellDestination.calendar:
        return Icons.calendar_today_outlined;
      case ShellDestination.workspace:
        return Icons.work_outline;
      case ShellDestination.chat:
        return Icons.chat_bubble_outline;
      case ShellDestination.profile:
        return Icons.person_outline;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case ShellDestination.dashboard:
        return Icons.dashboard;
      case ShellDestination.calendar:
        return Icons.calendar_today;
      case ShellDestination.workspace:
        return Icons.work;
      case ShellDestination.chat:
        return Icons.chat_bubble;
      case ShellDestination.profile:
        return Icons.person;
    }
  }
}
