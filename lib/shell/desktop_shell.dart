import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell_destination.dart';
import 'widgets/shell_navigation_rail.dart';
import 'widgets/shell_top_bar.dart';

class DesktopShell extends StatefulWidget {
  final Widget child;
  final ShellDestination selectedDestination;
  final ValueChanged<ShellDestination>? onDestinationSelected;

  /// Top bar button for the page's main action; also triggered by N.
  final ShellPageAction? pageAction;

  /// Reloads the open page from the top bar or with R; null hides the
  /// refresh button.
  final Future<void> Function()? onRefresh;
  final VoidCallback? onTeamChanged;
  final VoidCallback? onOpenProfile;

  const DesktopShell({
    super.key,
    required this.child,
    this.selectedDestination = ShellDestination.dashboard,
    this.onDestinationSelected,
    this.pageAction,
    this.onRefresh,
    this.onTeamChanged,
    this.onOpenProfile,
  });

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final _topBarKey = GlobalKey<ShellTopBarState>();

  // A global handler rather than a Shortcuts widget: clicking empty space
  // moves focus above the shell, where a Shortcuts widget would stop seeing
  // keys.
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    // Leave browser and system shortcuts such as Ctrl+R alone.
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    // A dialog or pushed page is on top of the shell.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (_isTyping()) return false;

    final key = event.logicalKey;
    final pageAction = widget.pageAction;
    if (key == LogicalKeyboardKey.keyN && pageAction != null) {
      pageAction.onPressed();
      return true;
    }
    if (key == LogicalKeyboardKey.keyR && widget.onRefresh != null) {
      _topBarKey.currentState?.refresh();
      return true;
    }
    return false;
  }

  /// Single-letter shortcuts must not fire while the user types in a field.
  bool _isTyping() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellNavigationRail(
            selectedDestination: widget.selectedDestination,
            onDestinationSelected: widget.onDestinationSelected,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShellTopBar(
                  key: _topBarKey,
                  destination: widget.selectedDestination,
                  pageAction: widget.pageAction,
                  onRefresh: widget.onRefresh,
                  onTeamChanged: widget.onTeamChanged,
                  onOpenProfile: widget.onOpenProfile,
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
