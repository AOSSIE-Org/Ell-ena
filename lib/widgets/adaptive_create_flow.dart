import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/app_shell.dart';

/// Opens a create form ([screen]) as a full page on phones and as a dialog on
/// wide screens. The form closes itself with `Navigator.pop(context, result)`
/// either way, so callers read the same result.
Future<T?> openCreateFlow<T>(
  BuildContext context,
  Widget screen, {
  bool fullscreenDialog = false,
}) {
  if (!AppShell.isDesktop(context)) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (context) => screen,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) {
      final height = math.min(840.0, MediaQuery.sizeOf(context).height - 96);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(width: 640, height: height, child: screen),
      );
    },
  );
}
