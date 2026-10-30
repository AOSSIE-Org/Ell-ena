import 'package:ell_ena/widgets/adaptive_create_flow.dart';
import 'package:ell_ena/widgets/detail_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for a detail or create screen: its own Scaffold and app bar, and
/// a button that closes it with a result, like delete or save does.
class _FakeScreen extends StatelessWidget {
  final String label;
  const _FakeScreen(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('finish'),
      ),
    );
  }
}

void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('DetailSidePanel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required String item,
      required VoidCallback onClose,
    }) async {
      setWindow(tester, const Size(1440, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailPanelLayout(
              content: const Text('list'),
              panel: DetailSidePanel(
                itemKey: item,
                onClose: onClose,
                child: _FakeScreen('detail $item'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the detail beside the list with a close button',
        (tester) async {
      await pumpPanel(tester, item: 'a', onClose: () {});

      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail a'), findsOneWidget);
      expect(find.byType(CloseButton), findsOneWidget);
    });

    testWidgets('close button closes the panel', (tester) async {
      var closed = 0;
      await pumpPanel(tester, item: 'a', onClose: () => closed++);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets("the detail screen's own pop closes the panel",
        (tester) async {
      var closed = 0;
      await pumpPanel(tester, item: 'a', onClose: () => closed++);

      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();

      expect(closed, 1);
      // The page under the panel is untouched.
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('switching items swaps the detail without closing',
        (tester) async {
      var closed = 0;
      await pumpPanel(tester, item: 'a', onClose: () => closed++);
      await pumpPanel(tester, item: 'b', onClose: () => closed++);

      expect(find.text('detail b'), findsOneWidget);
      expect(closed, 0);
    });

    testWidgets('phones show only the content', (tester) async {
      setWindow(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailPanelLayout(
              content: const Text('list'),
              panel: DetailSidePanel(
                itemKey: 'a',
                onClose: () {},
                child: const _FakeScreen('detail a'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail a'), findsNothing);
    });
  });

  group('openCreateFlow', () {
    Future<Object?> openAndFinish(WidgetTester tester, Size size) async {
      setWindow(tester, size);
      Object? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await openCreateFlow(
                  context,
                  const _FakeScreen('create'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opens a dialog on wide screens', (tester) async {
      await openAndFinish(tester, const Size(1440, 900));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('create'), findsOneWidget);
    });

    testWidgets('opens a full page on phones', (tester) async {
      await openAndFinish(tester, const Size(390, 844));

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('create'), findsOneWidget);
    });

    testWidgets('returns the form result from the dialog', (tester) async {
      setWindow(tester, const Size(1440, 900));
      Object? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await openCreateFlow(
                  context,
                  const _FakeScreen('create'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
