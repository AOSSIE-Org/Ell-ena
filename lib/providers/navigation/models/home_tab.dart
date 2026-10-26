/// Primary destinations for [HomeScreen] bottom navigation.
enum HomeTab {
  dashboard,
  calendar,
  workspace,
  chat,
  profile;

  static HomeTab fromIndex(int index) {
    if (index < 0 || index >= HomeTab.values.length) {
      return HomeTab.dashboard;
    }
    return HomeTab.values[index];
  }
}
