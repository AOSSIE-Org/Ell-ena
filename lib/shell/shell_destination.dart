import 'package:flutter/material.dart';

enum ShellDestination {
  dashboard,
  calendar,
  workspace,
  chat,
  profile;

  String get label {
    switch (this) {
      case ShellDestination.dashboard:
        return 'Dashboard';
      case ShellDestination.calendar:
        return 'Calendar';
      case ShellDestination.workspace:
        return 'Workspace';
      case ShellDestination.chat:
        return 'Chat';
      case ShellDestination.profile:
        return 'Profile';
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
