import 'package:flutter/material.dart';

import '../shell/app_shell.dart';

/// Shows a detail screen beside a list on wide screens.
///
/// The detail screen runs in its own Navigator, so it keeps its app bar and
/// actions unchanged: as a full-screen-dialog page its back arrow becomes a
/// close button, and its own `Navigator.pop` calls (for example after a
/// delete) close the panel instead of leaving the page.
class DetailSidePanel extends StatelessWidget {
  /// Identifies the open item; a new key swaps in a new detail page.
  final Object itemKey;
  final Widget child;
  final VoidCallback onClose;

  const DetailSidePanel({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final detailKey = ValueKey<Object>(itemKey);
    return ClipRect(
      child: Navigator(
        pages: [
          // Gives the detail page something to pop to, which is what makes
          // its app bar show a close button.
          const MaterialPage<void>(child: SizedBox.shrink()),
          MaterialPage<void>(
            key: detailKey,
            fullscreenDialog: true,
            child: child,
          ),
        ],
        onDidRemovePage: (page) {
          // Swapping to another item also removes the old page; only the
          // open item's page leaving means the user closed it.
          if (page.key == detailKey) onClose();
        },
      ),
    );
  }
}

/// On wide screens, places [panel] beside [content], taking 40% of the width within
/// 360–480px so the list keeps usable room on smaller wide windows.
class DetailPanelLayout extends StatelessWidget {
  final Widget content;
  final Widget? panel;

  const DetailPanelLayout({super.key, required this.content, this.panel});

  @override
  Widget build(BuildContext context) {
    if (!AppShell.isDesktop(context)) return content;
    final panel = this.panel;
    // The row stays in place whether or not the panel is open, so opening
    // it does not rebuild the list and lose its scroll position.
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = (constraints.maxWidth * 0.4).clamp(360.0, 480.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: content),
            if (panel != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(width: panelWidth, child: panel),
            ],
          ],
        );
      },
    );
  }
}
