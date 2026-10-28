import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/widgets/chat/rag_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester,
    RagResult result, {
    VoidCallback? onTap,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RagResultTile(result: result, onTap: onTap)),
      ),
    );
  }

  /// The entity icon leads the row, before the optional chevron.
  Icon entityIcon(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon).first);

  testWidgets('task shows status and due date, and is tappable',
      (tester) async {
    final due = DateTime(2026, 11, 3, 12);
    var taps = 0;
    await pumpTile(
      tester,
      RagResult(
        entityType: RagEntityType.task,
        entityId: 'task-1',
        title: 'Ship release',
        status: 'in_progress',
        dueDate: due,
        content: 'never shown when metadata exists',
      ),
      onTap: () => taps++,
    );

    expect(find.text('Ship release'), findsOneWidget);
    expect(
      find.text('In Progress · Due ${DateFormat.yMMMd().format(due)}'),
      findsOneWidget,
    );
    expect(find.textContaining('never shown'), findsNothing);
    // The id is used for navigation only and never rendered.
    expect(find.textContaining('task-1'), findsNothing);
    expect(entityIcon(tester).icon, Icons.task_alt);

    await tester.tap(find.byType(RagResultTile));
    expect(taps, 1);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('ticket shows status and priority', (tester) async {
    await pumpTile(
      tester,
      const RagResult(
        entityType: RagEntityType.ticket,
        entityId: 't',
        title: 'Login broken',
        status: 'open',
        priority: 'high',
      ),
    );

    expect(find.text('Open · High'), findsOneWidget);
    expect(entityIcon(tester).icon, Icons.confirmation_number_outlined);
    // Not tappable without a callback.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('meeting shows its date and time', (tester) async {
    final at = DateTime(2026, 11, 3, 15, 30);
    await pumpTile(
      tester,
      RagResult(
        entityType: RagEntityType.meeting,
        entityId: 'm',
        title: 'Planning',
        meetingDate: at,
      ),
    );

    expect(
      find.text(DateFormat('MMM d, y · h:mm a').format(at)),
      findsOneWidget,
    );
    expect(entityIcon(tester).icon, Icons.event);
  });

  testWidgets('without metadata falls back to a trimmed content preview',
      (tester) async {
    final longText = 'word ' * 30;
    await pumpTile(
      tester,
      RagResult(
        entityType: RagEntityType.unknown,
        entityId: 'x',
        title: 'Notes',
        content: '  $longText  ',
      ),
      brightness: Brightness.dark,
    );

    final preview = '${longText.trim().substring(0, 80)}…';
    expect(find.text(preview), findsOneWidget);
    expect(entityIcon(tester).icon, Icons.article_outlined);
  });

  testWidgets('short content is shown in full; empty fields show no subtitle',
      (tester) async {
    await pumpTile(
      tester,
      const RagResult(
        entityType: RagEntityType.task,
        entityId: 'a',
        title: 'Short',
        status: '',
        content: 'Just this',
      ),
    );
    expect(find.text('Just this'), findsOneWidget);

    await pumpTile(
      tester,
      const RagResult(
        entityType: RagEntityType.ticket,
        entityId: 'b',
        title: 'Bare',
        priority: '',
        content: '   ',
      ),
    );
    // Only the title remains.
    expect(find.byType(Text), findsOneWidget);
  });
}
