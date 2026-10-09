import '../providers/navigation/models/home_tab.dart';

/// Typed route paths for Ell-ena navigation.
class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const home = '/home';
  static const calendar = '/calendar';
  static const workspace = '/workspace';
  static const tasks = '/tasks';
  static const tickets = '/tickets';
  static const meetings = '/meetings';
  static const chat = '/chat';
  static const profile = '/profile';

  static const shellPaths = <String>{
    home,
    calendar,
    workspace,
    tasks,
    tickets,
    meetings,
    chat,
    profile,
  };

  /// Primary shell destinations exposed through [HomeTab] bottom navigation.
  static String pathForHomeTab(HomeTab tab) {
    switch (tab) {
      case HomeTab.dashboard:
        return home;
      case HomeTab.calendar:
        return calendar;
      case HomeTab.workspace:
        return workspace;
      case HomeTab.chat:
        return chat;
      case HomeTab.profile:
        return profile;
    }
  }

  static HomeTab homeTabForPath(String path) {
    switch (path) {
      case calendar:
        return HomeTab.calendar;
      case workspace:
      case tasks:
      case tickets:
      case meetings:
        return HomeTab.workspace;
      case chat:
        return HomeTab.chat;
      case profile:
        return HomeTab.profile;
      case home:
      default:
        return HomeTab.dashboard;
    }
  }

  /// Workspace TabBar index for deep-link paths, or null for generic workspace.
  static int? workspaceTabIndexForPath(String path) {
    switch (path) {
      case tasks:
        return 0;
      case tickets:
        return 1;
      case meetings:
        return 2;
      default:
        return null;
    }
  }

  static String pathForWorkspaceTabIndex(int index) {
    switch (index) {
      case 0:
        return tasks;
      case 1:
        return tickets;
      case 2:
        return meetings;
      default:
        return workspace;
    }
  }

  static HomeTab homeTabForScreenIndex(int index) =>
      HomeTab.fromIndex(index);
}
