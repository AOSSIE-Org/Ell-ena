import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../router/app_routes.dart';

/// Pages of the wide-screen shell. Phones keep the bottom bar and the
/// Workspace tabs; here Tasks, Tickets and Meetings are pages of their own.
enum ShellDestination {
  dashboard,
  calendar,
  tasks,
  tickets,
  meetings,
  chat,
  profile;

  /// Listed in the sidebar. Profile is reached from the account menu.
  static const sidebar = <ShellDestination>[
    dashboard,
    calendar,
    tasks,
    tickets,
    meetings,
    chat,
  ];

  String get path {
    switch (this) {
      case ShellDestination.dashboard:
        return AppRoutes.home;
      case ShellDestination.calendar:
        return AppRoutes.calendar;
      case ShellDestination.tasks:
        return AppRoutes.tasks;
      case ShellDestination.tickets:
        return AppRoutes.tickets;
      case ShellDestination.meetings:
        return AppRoutes.meetings;
      case ShellDestination.chat:
        return AppRoutes.chat;
      case ShellDestination.profile:
        return AppRoutes.profile;
    }
  }

  /// `/workspace` has no page of its own here, so it opens Tasks, matching the
  /// Workspace screen's first tab.
  static ShellDestination fromPath(String path) {
    switch (path) {
      case AppRoutes.calendar:
        return ShellDestination.calendar;
      case AppRoutes.workspace:
      case AppRoutes.tasks:
        return ShellDestination.tasks;
      case AppRoutes.tickets:
        return ShellDestination.tickets;
      case AppRoutes.meetings:
        return ShellDestination.meetings;
      case AppRoutes.chat:
        return ShellDestination.chat;
      case AppRoutes.profile:
        return ShellDestination.profile;
      case AppRoutes.home:
      default:
        return ShellDestination.dashboard;
    }
  }

  /// Chat is a conversation, not a data view, so it has nothing to refresh.
  bool get canRefresh => this != ShellDestination.chat;

  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case ShellDestination.dashboard:
        return l10n.dashboard;
      case ShellDestination.calendar:
        return l10n.calendar;
      case ShellDestination.tasks:
        return l10n.tasks;
      case ShellDestination.tickets:
        return l10n.tickets;
      case ShellDestination.meetings:
        return l10n.meetings;
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
      case ShellDestination.tasks:
        return Icons.task_outlined;
      case ShellDestination.tickets:
        return Icons.confirmation_number_outlined;
      case ShellDestination.meetings:
        return Icons.group_outlined;
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
      case ShellDestination.tasks:
        return Icons.task;
      case ShellDestination.tickets:
        return Icons.confirmation_number;
      case ShellDestination.meetings:
        return Icons.group;
      case ShellDestination.chat:
        return Icons.chat_bubble;
      case ShellDestination.profile:
        return Icons.person;
    }
  }
}
