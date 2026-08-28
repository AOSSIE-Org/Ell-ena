import 'dart:convert';

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

    test('caps expanded meeting summary at maxContentChars', () {
      final points = List.generate(
        40,
        (i) => 'Discussion point number $i with extra detail for length',
      );
      final payload = {
        'overall_summary': 'A' * 400,
        'key_discussion_points': points,
        'important_decisions': ['Ship OAuth fix', 'Defer dark mode'],
        'action_items': [
          {
            'item': 'Patch redirect',
            'owner': 'Aarav',
            'deadline': '2026-08-30',
          },
        ],
      };
      final jsonMeeting = RagResult(
        entityType: RagEntityType.meeting,
        entityId: 'meet-long',
        title: 'Sprint planning',
        meetingDate: DateTime.utc(2026, 8, 20, 14, 30),
        content: jsonEncode(payload),
      );

      final formatted = AiContextBuilder.formatResult(jsonMeeting);

      expect(formatted, contains('Sprint planning'));
      expect(formatted, contains('id: meet-long'));
      expect(formatted, contains('2026-08-20 at 14:30'));
      expect(
        formatted.length,
        lessThanOrEqualTo(AiContextBuilder.maxContentChars + 1),
      );
      expect(formatted, endsWith('…'));
    });

    test('preserves hybrid ranking order in formatted context', () {
      final first = const RagResult(
        entityType: RagEntityType.ticket,
        entityId: 't1',
        title: 'First by score',
        content: 'ticket body',
        finalScore: 0.9,
      );
      final second = const RagResult(
        entityType: RagEntityType.task,
        entityId: 't2',
        title: 'Second by score',
        content: 'task body',
        finalScore: 0.7,
      );
      final third = RagResult(
        entityType: RagEntityType.meeting,
        entityId: 't3',
        title: 'Third by score',
        content: '{"overall_summary":"short"}',
        finalScore: 0.5,
      );

      final formatted = AiContextBuilder.formatResults([first, second, third]);

      final i1 = formatted.indexOf('First by score');
      final i2 = formatted.indexOf('Second by score');
      final i3 = formatted.indexOf('Third by score');
      expect(i1, lessThan(i2));
      expect(i2, lessThan(i3));
    });

    test('task and ticket formatting still truncates content', () {
      final long = 'y' * 800;
      final task = AiContextBuilder.formatResult(RagResult(
        entityType: RagEntityType.task,
        entityId: 'task-cap',
        title: 'Task title',
        content: long,
      ));
      final ticket = AiContextBuilder.formatResult(RagResult(
        entityType: RagEntityType.ticket,
        entityId: 'tick-cap',
        title: 'Ticket title',
        content: long,
      ));

      expect(task, contains('Task: Task title'));
      expect(ticket, contains('Ticket: Ticket title'));
      expect(task, contains('…'));
      expect(ticket, contains('…'));
      expect(task.length, lessThan(long.length));
      expect(ticket.length, lessThan(long.length));
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

    test('summarizeTasks leaves lists of 20 or fewer unchanged in length', () {
      final tasks = List.generate(
        20,
        (i) => {
          'id': 'task-$i',
          'title': 'Task $i',
          'status': 'todo',
          'due_date': null,
          'assigned_to': null,
        },
      );

      final summarized = AiContextBuilder.summarizeTasks(tasks);

      expect(summarized, hasLength(20));
      expect(summarized.first['id'], 'task-0');
      expect(summarized.last['id'], 'task-19');
    });

    test('summarizeTasks caps lists longer than maxToolResults', () {
      final tasks = List.generate(
        35,
        (i) => {
          'id': 'task-$i',
          'title': 'Task $i',
          'status': 'todo',
          'due_date': null,
          'assigned_to': null,
          'description': 'keep-me-$i',
        },
      );
      final originalLength = tasks.length;
      final firstDescription = tasks.first['description'];

      final summarized = AiContextBuilder.summarizeTasks(tasks);

      expect(summarized, hasLength(AiContextBuilder.maxToolResults));
      expect(summarized.first['id'], 'task-0');
      expect(summarized.last['id'], 'task-19');
      expect(
        summarized.any((row) => row['id'] == 'task-20'),
        isFalse,
      );
      // Original list and row fields are not modified.
      expect(tasks, hasLength(originalLength));
      expect(tasks.first['description'], firstDescription);
      expect(tasks[20]['id'], 'task-20');
    });

    test('summarizeTickets caps and preserves summary fields', () {
      final tickets = List.generate(
        25,
        (i) => {
          'id': 'tick-$i',
          'title': 'Ticket $i',
          'status': 'open',
          'priority': 'medium',
          'category': 'Bug',
          'assigned_to': 'user-1',
          'embedding': [0.1],
          'assignee': {'full_name': 'Aarav'},
        },
      );

      final summarized = AiContextBuilder.summarizeTickets(tickets);

      expect(summarized, hasLength(AiContextBuilder.maxToolResults));
      expect(summarized.first['title'], 'Ticket 0');
      expect(summarized.first['priority'], 'medium');
      expect(summarized.first['assigned_to_name'], 'Aarav');
      expect(summarized.first.containsKey('embedding'), isFalse);
      expect(tickets, hasLength(25));
    });
  });
}
