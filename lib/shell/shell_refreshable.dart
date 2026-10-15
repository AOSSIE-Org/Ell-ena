/// A page whose data the wide-screen top bar can reload, in place of
/// pull-to-refresh.
abstract class ShellRefreshable {
  Future<void> refreshFromShell();
}
