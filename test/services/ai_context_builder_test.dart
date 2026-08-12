import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/ai_context_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiContextBuilder', () {
    final authMeeting = RagResult(
      entityType: RagEntityType.meeting,
      entityId: 'meet-auth',
      title: 'Auth discussion',
      content:
          '{"overall_summary":"Team agreed to fix OAuth redirect","key_discussion_points":["Google sign-in fails"]}',
    );
    final authTicket = const RagResult(
      entityType: RagEntityType.ticket,
      entityId: 'tick-auth',
      title: 'OAuth redirect broken',
      content: 'Users bounce after Google consent.',
    );
    final unrelatedTask = const RagResult(
      entityType: RagEntityType.task,
      entityId: 'task-office',
      title: 'Order office snacks',
      content: 'Buy granola bars',
    );

    test('converts retrieved results into targeted AI context', () {
      final outcome = RagRetrievalOutcome.success([authMeeting, authTicket]);

      final context = AiContextBuilder.buildWorkspaceContext(outcome);

      expect(context, contains('Relevant workspace context:'));
      expect(context, contains('Auth discussion'));
      expect(context, contains('id: meet-auth'));
      expect(context, contains('OAuth redirect broken'));
      expect(context, contains('id: tick-auth'));
      expect(context, contains('Team agreed to fix OAuth redirect'));
      expect(context, isNot(contains('similarity')));
    });

    test('does not include records that were not retrieved', () {
      final outcome = RagRetrievalOutcome.success([authMeeting, authTicket]);

      final context = AiContextBuilder.buildWorkspaceContext(outcome);

      expect(context, isNot(contains('Order office snacks')));
      expect(context, isNot(contains('task-office')));
      expect(context, isNot(contains('granola')));
      expect(
        AiContextBuilder.formatResults([unrelatedTask]),
        isNot(contains(context)),
      );
    });

    test('returns empty context when retrieval is empty', () {
      const outcome = RagRetrievalOutcome.empty();

      expect(AiContextBuilder.buildWorkspaceContext(outcome), isEmpty);
    });

    test('returns empty context when retrieval errors', () {
      const outcome =
          RagRetrievalOutcome.error('Could not search workspace context.');

      expect(AiContextBuilder.buildWorkspaceContext(outcome), isEmpty);
    });

    test('truncates long descriptions', () {
      final longContent = 'x' * 900;
      final result = RagResult(
        entityType: RagEntityType.task,
        entityId: 'long-1',
        title: 'Long task',
        content: longContent,
      );

      final formatted = AiContextBuilder.formatResult(result);

      expect(formatted.length, lessThan(longContent.length));
      expect(formatted, contains('…'));
    });

    test('summarizes tool rows without dumping full database fields', () {
      final summarized = AiContextBuilder.summarizeTask({
        'id': 'task-1',
        'title': 'Fix login',
        'status': 'todo',
        'due_date': '2026-08-12',
        'assigned_to': 'user-1',
        'description': 'very long unused field',
        'embedding': [0.1, 0.2],
        'created_at': '2026-01-01',
        'assignee': {'full_name': 'Aarav'},
      });

      expect(
          summarized.keys, containsAll(['id', 'title', 'status', 'due_date']));
      expect(summarized['assigned_to_name'], 'Aarav');
      expect(summarized.containsKey('embedding'), isFalse);
      expect(summarized.containsKey('description'), isFalse);
      expect(summarized.containsKey('created_at'), isFalse);
    });
  });
}
