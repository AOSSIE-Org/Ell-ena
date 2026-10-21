import 'package:ell_ena/widgets/social_share_button.dart';
import 'package:ell_ena/widgets/social_share_host_stub.dart';
import 'package:ell_ena/widgets/support_us_host_stub.dart';
import 'package:ell_ena/widgets/support_us_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// These widgets embed web-only JavaScript components. Android, iOS, and
/// desktop builds use the stubs, which must draw and do nothing.
void main() {
  testWidgets('the share slot is empty outside the web, even when wide',
      (tester) async {
    await pumpApp(tester, const Scaffold(body: SocialShareSlot()),
        size: wideSize);

    expect(find.byType(SocialShareHost), findsNothing);
    expect(tester.getSize(find.byType(SocialShareSlot)), Size.zero);
  });

  testWidgets('the stub share host draws nothing', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Center(child: SocialShareHost(key: UniqueKey(), theme: 'dark')),
      ),
    );

    expect(tester.getSize(find.byType(SocialShareHost)), Size.zero);
  });

  testWidgets('opening Support Us outside the web shows nothing',
      (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSupportUs(context),
            child: const Text('support'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('support'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('support'), findsOneWidget);
    // The stub overlay is a no-op too.
    showSupportOverlay('light');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
