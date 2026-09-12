import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/chat_controller.dart';
import 'package:ell_ena/services/rag_retriever.dart';
import 'package:ell_ena/widgets/chat/context_insights_panel.dart';
import 'package:ell_ena/widgets/chat/rag_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupRagResultsByType', () {
    test('preserves hybrid ranking order within each section', () {
      final results = [
        const RagResult(
          entityType: RagEntityType.ticket,
          entityId: 't1',
          title: 'Ticket first',
          finalScore: 0.9,
        ),
        const RagResult(
          entityType: RagEntityType.task,
          entityId: 'task-1',
          title: 'Task A',
          finalScore: 0.8,
        ),
        const RagResult(
          entityType: RagEntityType.task,
          entityId: 'task-2',
          title: 'Task B',
          finalScore: 0.7,
        ),
        RagResult(
          entityType: RagEntityType.meeting,
          entityId: 'm1',
          title: 'Planning',
          finalScore: 0.6,
        ),
      ];

      final grouped = groupRagResultsByType(results);

      expect(grouped[RagEntityType.task]!.map((r) => r.title).toList(),
          ['Task A', 'Task B']);
      expect(grouped[RagEntityType.ticket]!.single.title, 'Ticket first');
      expect(grouped[RagEntityType.meeting]!.single.title, 'Planning');
    });
  });

  group('ContextInsightsBody', () {
    testWidgets('shows idle empty state before retrieval', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextInsightsBody(
              retrievalStatus: RagRetrievalStatus.idle,
              results: const [],
            ),
          ),
        ),
      );

      expect(find.text('Context'), findsOneWidget);
      expect(find.text('No context yet'), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContextInsightsBody(
              retrievalStatus: RagRetrievalStatus.loading,
              results: [],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContextInsightsBody(
              retrievalStatus: RagRetrievalStatus.error,
              results: [],
              errorMessage: 'Could not search workspace context.',
            ),
          ),
        ),
      );

      expect(find.text('Could not load context'), findsOneWidget);
      expect(find.text('Could not search workspace context.'), findsOneWidget);
    });

    testWidgets('shows empty retrieval state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContextInsightsBody(
              retrievalStatus: RagRetrievalStatus.empty,
              results: [],
            ),
          ),
        ),
      );

      expect(find.text('No matches found'), findsOneWidget);
    });

    testWidgets('renders categorized task, ticket, and meeting results',
        (tester) async {
      RagResult? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextInsightsBody(
              retrievalStatus: RagRetrievalStatus.success,
              results: const [
                RagResult(
                  entityType: RagEntityType.task,
                  entityId: 'task-1',
                  title: 'Fix login',
                  status: 'todo',
                ),
                RagResult(
                  entityType: RagEntityType.ticket,
                  entityId: 'tick-1',
                  title: 'OAuth bug',
                  priority: 'high',
                ),
                RagResult(
                  entityType: RagEntityType.meeting,
                  entityId: 'meet-1',
                  title: 'Sprint planning',
                  meetingDate: null,
                ),
              ],
              onResultTap: (result) => tapped = result,
            ),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Meetings'), findsOneWidget);
      expect(find.text('Fix login'), findsOneWidget);
      expect(find.text('OAuth bug'), findsOneWidget);
      expect(find.text('Sprint planning'), findsOneWidget);

      await tester.tap(find.text('Fix login'));
      await tester.pumpAndSettle();

      expect(tapped?.entityId, 'task-1');
      expect(tapped?.entityType, RagEntityType.task);
    });
  });

  group('ContextInsightsPanel', () {
    testWidgets('updates when ChatState retrievalResults change',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(
            RagRetriever(
              rpc: (functionName, {params}) async {
                if (functionName == 'queue_embedding') return 1;
                return [
                  {
                    'entity_type': 'ticket',
                    'entity_id': 'tick-auth',
                    'title': 'OAuth redirect broken',
                    'content': 'Users bounce after Google consent.',
                    'similarity': 0.88,
                  },
                ];
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ContextInsightsPanel(),
            ),
          ),
        ),
      );

      expect(find.text('No context yet'), findsOneWidget);

      await container
          .read(chatControllerProvider.notifier)
          .retrieveForQuery('authentication');
      await tester.pumpAndSettle();

      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('OAuth redirect broken'), findsOneWidget);
    });
  });

  group('RagResultTile', () {
    testWidgets('shows task metadata in subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RagResultTile(
              result: RagResult(
                entityType: RagEntityType.task,
                entityId: 'task-1',
                title: 'Fix login',
                status: 'in_progress',
                dueDate: DateTime.utc(2026, 8, 30),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Fix login'), findsOneWidget);
      expect(find.textContaining('In Progress'), findsOneWidget);
      expect(find.textContaining('Due'), findsOneWidget);
      expect(find.textContaining('task-1'), findsNothing);
      expect(find.textContaining('in_progress'), findsNothing);
    });
  });
}
