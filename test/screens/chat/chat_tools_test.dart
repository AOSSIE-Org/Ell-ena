import 'package:ell_ena/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'speech_mock.dart';

const _geminiPath = '/v1beta/models/gemini-2.5-flash:generateContent';
const _bobUuid = '22222222-2222-4222-8222-222222222222';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() async {
    mockSpeech();
    await resetFakeSupabase();
  });

  Future<void> pumpChat(WidgetTester tester) async {
    await pumpApp(tester, const ChatScreen(), size: const Size(480, 1600));
    await settle(tester);
  }

  /// Has Gemini answer the next message with a call to [name], then with
  /// `Done: [name]` once the tool result is sent back. Returns that result.
  Future<Map<String, dynamic>> callTool(
    WidgetTester tester,
    String name,
    Map<String, dynamic> args,
  ) async {
    backend.geminiHandler = (body) => body.containsKey('tools')
        ? FakeBackend.geminiCall(name, args)
        : FakeBackend.geminiText('Done: $name');
    final before = backend.bodiesFor('POST', _geminiPath).length;

    await tester.enterText(find.byType(TextField), 'Please $name');
    await tester.tap(find.byTooltip('Send message'));
    await settle(tester, frames: 20);

    final bodies = backend.bodiesFor('POST', _geminiPath);
    expect(bodies.length, before + 2, reason: 'request and tool follow-up');
    final followUp = (bodies.last as Map)['contents'] as List;
    final response =
        (followUp.last as Map)['parts'][0]['functionResponse'] as Map;
    expect(response['name'], name);
    return Map<String, dynamic>.from(response['response']['content'] as Map);
  }

  List<Map<String, dynamic>> inserted(String table) => [
        for (final body in backend.bodiesFor('POST', '/rest/v1/$table'))
          Map<String, dynamic>.from(body as Map),
      ];

  List<Map<String, dynamic>> patched(String table) => [
        for (final body in backend.bodiesFor('PATCH', '/rest/v1/$table'))
          Map<String, dynamic>.from(body as Map),
      ];

  testWidgets('create_task resolves the assignee and shows a task card',
      (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);

      final result = await callTool(tester, 'create_task', {
        'title': 'Draft agenda',
        'description': 'For Monday',
        'due_date': '2026-11-05',
        'assigned_to': 'bob',
      });

      expect(result['success'], isTrue);
      final task = inserted('tasks').single;
      expect(task['title'], 'Draft agenda');
      expect(task['assigned_to'], 'user-2');
      expect(task['due_date'], startsWith('2026-11-05'));

      expect(
          find.text("I'll help you with that. Let me process your request..."),
          findsOneWidget);
      expect(find.text('Done: create_task'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Draft agenda'), findsOneWidget);
      expect(find.text('View Task'), findsOneWidget);
    });
  });

  testWidgets('create_task keeps UUID assignees and skips unknown names',
      (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);

      await callTool(tester, 'create_task', {
        'title': 'By id',
        'due_date': 'next week',
        'assigned_to': _bobUuid,
      });
      await callTool(tester, 'create_task', {
        'title': 'Nobody',
        'assigned_to': 'Grace',
      });

      final tasks = inserted('tasks');
      expect(tasks[0]['assigned_to'], _bobUuid);
      // An unparseable due date is dropped rather than failing the task.
      expect(tasks[0].containsKey('due_date'), isFalse);
      expect(tasks[1].containsKey('assigned_to'), isFalse);
    });
  });

  testWidgets('create_ticket sends priority and category', (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);

      final result = await callTool(tester, 'create_ticket', {
        'title': 'Crash on save',
        'description': 'Every time',
        'priority': 'high',
        'category': 'Bug',
        'assigned_to': 'ADA',
      });
      await callTool(tester, 'create_ticket', {
        'title': 'By id',
        'priority': 'low',
        'category': 'Other',
        'assigned_to': _bobUuid,
      });
      await callTool(tester, 'create_ticket', {
        'title': 'Unassigned',
        'priority': 'low',
        'category': 'Other',
        'assigned_to': 'Grace',
      });

      expect(result['success'], isTrue);
      final tickets = inserted('tickets');
      expect(tickets[0]['priority'], 'high');
      expect(tickets[0]['category'], 'Bug');
      expect(tickets[0]['assigned_to'], FakeBackend.userId);
      expect(tickets[0]['sync_to_github'], isFalse);
      expect(tickets[1]['assigned_to'], _bobUuid);
      expect(tickets[2].containsKey('assigned_to'), isFalse);
      expect(find.text('New Ticket'), findsNWidgets(3));
      expect(find.text('View Ticket'), findsNWidgets(3));
    });
  });

  testWidgets('create_meeting schedules valid dates only', (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);

      final ok = await callTool(tester, 'create_meeting', {
        'title': 'Kickoff',
        'meeting_date': '2026-11-04T10:00:00',
        'meeting_url': 'https://meet.example/abc',
      });
      final bad = await callTool(tester, 'create_meeting', {
        'title': 'Whenever',
        'meeting_date': 'someday',
      });

      expect(ok['success'], isTrue);
      expect(inserted('meetings').single['meeting_url'],
          'https://meet.example/abc');
      expect(bad, {'success': false, 'error': 'Invalid meeting date format'});
      // Only the scheduled meeting gets a card.
      expect(find.text('View Meeting'), findsOneWidget);
      expect(find.text('Nov 4, 2026 • 10:00 AM'), findsOneWidget);
    });
  });

  testWidgets('missing required arguments fail without crashing',
      (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);

      final task = await callTool(tester, 'create_task', {});
      final ticket = await callTool(tester, 'create_ticket', {'title': 'x'});
      final meeting = await callTool(tester, 'create_meeting', {});
      final unknown = await callTool(tester, 'delete_everything', {});

      expect(task['success'], isFalse);
      expect(ticket['success'], isFalse);
      expect(meeting['success'], isFalse);
      expect(unknown, {'success': false, 'error': 'Unknown function'});
      expect(inserted('tasks'), isEmpty);
      expect(find.text('View Task'), findsNothing);
    });
  });

  group('queries', () {
    void seedTasks() {
      backend.table('tasks').addAll([
        {
          'id': 'a',
          'title': 'Ada todo',
          'status': 'todo',
          'team_id': FakeBackend.teamId,
          'assigned_to': FakeBackend.userId,
          'created_at': '2026-10-01T00:00:00',
        },
        {
          'id': 'b',
          'title': 'Bob todo',
          'status': 'todo',
          'team_id': FakeBackend.teamId,
          'assigned_to': 'user-2',
          'created_at': '2026-10-02T00:00:00',
        },
        {
          'id': 'c',
          'title': 'Bob done',
          'status': 'completed',
          'team_id': FakeBackend.teamId,
          'assigned_to': 'user-2',
          'created_at': '2026-10-03T00:00:00',
        },
      ]);
    }

    List<String> titles(Map<String, dynamic> result, String key) => [
          for (final item in result[key] as List) '${(item as Map)['title']}',
        ];

    testWidgets('query_tasks filters by status, member and assignment',
        (tester) async {
      await withFakeHttp(() async {
        seedTasks();
        await pumpChat(tester);

        final bobTodo = await callTool(tester, 'query_tasks', {
          'status': 'todo',
          'assigned_to_team_member': 'Bob',
        });
        final bobAll = await callTool(tester, 'query_tasks', {
          'status': 'all',
          'assigned_to_team_member': 'bo',
        });
        final byId = await callTool(tester, 'query_tasks', {
          'assigned_to_team_member': _bobUuid,
        });
        final unknown = await callTool(tester, 'query_tasks', {
          'assigned_to_team_member': 'Grace',
        });
        final mine = await callTool(tester, 'query_tasks', {
          'assigned_to_me': true,
          'due_date': '2026-10-02',
        });
        final broken = await callTool(tester, 'query_tasks', {'status': 3});

        // Member filtering happens in the screen, by resolved user id.
        expect(titles(bobTodo, 'tasks'), everyElement(startsWith('Bob')));
        expect(titles(bobTodo, 'tasks'), contains('Bob todo'));
        expect(titles(bobAll, 'tasks')..sort(), ['Bob done', 'Bob todo']);
        expect(byId['count'], 0);
        // An unknown name falls back to the whole team.
        expect(unknown['count'], 3);
        expect(mine['success'], isTrue);
        expect(broken, {'success': false, 'error': 'Unable to query tasks.'});
      });
    });

    testWidgets('query_tickets filters by status, priority and member',
        (tester) async {
      await withFakeHttp(() async {
        backend.table('tickets').addAll([
          {
            'id': 'k1',
            'title': 'Bob high',
            'status': 'open',
            'priority': 'high',
            'team_id': FakeBackend.teamId,
            'assigned_to': 'user-2',
            'created_at': '2026-10-01T00:00:00',
          },
          {
            'id': 'k2',
            'title': 'Ada low',
            'status': 'open',
            'priority': 'low',
            'team_id': FakeBackend.teamId,
            'assigned_to': FakeBackend.userId,
            'created_at': '2026-10-02T00:00:00',
          },
        ]);
        await pumpChat(tester);

        final bob = await callTool(tester, 'query_tickets', {
          'status': 'open',
          'priority': 'all',
          'assigned_to_team_member': 'bob',
        });
        final partial = await callTool(tester, 'query_tickets', {
          'assigned_to_team_member': 'ad',
          'priority': 'low',
        });
        final byId = await callTool(tester, 'query_tickets', {
          'assigned_to_team_member': _bobUuid,
        });
        final unknown = await callTool(tester, 'query_tickets', {
          'assigned_to_team_member': 'Grace',
          'status': 'all',
        });
        final mine = await callTool(tester, 'query_tickets', {
          'assigned_to_me': true,
          'priority': 'high',
        });
        final broken =
            await callTool(tester, 'query_tickets', {'priority': false});

        expect(titles(bob, 'tickets'), ['Bob high']);
        expect(titles(partial, 'tickets'), ['Ada low']);
        expect(byId['count'], 0);
        expect(unknown['count'], 2);
        expect(mine['success'], isTrue);
        expect(broken, {'success': false, 'error': 'Unable to query tickets.'});
      });
    });
  });

  group('modify_item', () {
    testWidgets('updates task and ticket fields', (tester) async {
      await withFakeHttp(() async {
        backend.table('tasks').add({'id': 'task-1', 'status': 'todo'});
        backend.table('tickets').add({'id': 'ticket-1', 'status': 'open'});
        await pumpChat(tester);

        final task = await callTool(tester, 'modify_item', {
          'item_type': 'task',
          'item_id': 'task-1',
          'status': 'completed',
          'due_date': '2026-11-01',
          'assigned_to': 'bob',
        });
        final ticketStatus = await callTool(tester, 'modify_item', {
          'item_type': 'ticket',
          'item_id': 'ticket-1',
          'status': 'resolved',
          'assigned_to': 'ad',
        });
        final ticketPriority = await callTool(tester, 'modify_item', {
          'item_type': 'ticket',
          'item_id': 'ticket-1',
          'priority': 'critical',
          'assigned_to': _bobUuid,
        });
        final titleOnly = await callTool(tester, 'modify_item', {
          'item_type': 'task',
          'item_id': 'task-1',
          'title': 'Renamed',
          'assigned_to': 'Grace',
        });

        expect(task['success'], isTrue);
        expect(ticketStatus['success'], isTrue);
        expect(ticketPriority['success'], isTrue);
        expect(patched('tasks'), [
          {'status': 'completed'}
        ]);
        expect(patched('tickets'), [
          {'status': 'resolved'},
          {'priority': 'critical'},
        ]);
        expect(backend.table('tickets').single['priority'], 'critical');
        // Only status changes are supported for tasks.
        expect(titleOnly, {'success': false, 'error': 'No changes made'});
      });
    });

    testWidgets('updates a meeting, keeping fields that were not given',
        (tester) async {
      await withFakeHttp(() async {
        backend.table('meetings').add({
          'id': 'meeting-1',
          'title': 'Old title',
          'description': 'Keep me',
          'meeting_url': 'https://meet.example/x',
          'meeting_date': '2026-11-01T09:00:00',
          'team_id': FakeBackend.teamId,
        });
        await pumpChat(tester);

        final moved = await callTool(tester, 'modify_item', {
          'item_type': 'meeting',
          'item_id': 'meeting-1',
          'meeting_date': '2026-11-02T11:00:00',
        });
        final renamed = await callTool(tester, 'modify_item', {
          'item_type': 'meeting',
          'item_id': 'meeting-1',
          'title': 'New title',
          'description': 'New description',
        });
        final missing = await callTool(tester, 'modify_item', {
          'item_type': 'meeting',
          'item_id': 'nope',
          'title': 'Ghost',
        });

        expect(moved['success'], isTrue);
        expect(renamed['success'], isTrue);
        final updates = patched('meetings');
        expect(updates[0]['title'], 'Old title');
        expect(updates[0]['description'], 'Keep me');
        expect(updates[0]['meeting_date'], startsWith('2026-11-02T11:00'));
        expect(updates[1]['title'], 'New title');
        expect(updates[1]['meeting_date'], startsWith('2026-11-02T11:00'));
        expect(missing, {'success': false, 'error': 'No changes made'});
      });
    });

    testWidgets('rejects bad input', (tester) async {
      await withFakeHttp(() async {
        await pumpChat(tester);

        final badType = await callTool(tester, 'modify_item', {
          'item_type': 'project',
          'item_id': 'x',
          'title': 'y',
        });
        final noChanges = await callTool(tester, 'modify_item', {
          'item_type': 'ticket',
          'item_id': 'x',
        });
        final badDue = await callTool(tester, 'modify_item', {
          'item_type': 'task',
          'item_id': 'x',
          'due_date': 'tomorrow-ish',
        });
        final badMeetingDate = await callTool(tester, 'modify_item', {
          'item_type': 'meeting',
          'item_id': 'x',
          'meeting_date': 'later',
        });
        final noType = await callTool(tester, 'modify_item', {'item_id': 'x'});

        expect(badType, {'success': false, 'error': 'Invalid item type'});
        expect(noChanges, {'success': false, 'error': 'No changes specified'});
        expect(badDue, {'success': false, 'error': 'Invalid due date format'});
        expect(badMeetingDate,
            {'success': false, 'error': 'Invalid meeting date format'});
        expect(noType['success'], isFalse);
        expect(patched('tasks'), isEmpty);
      });
    });
  });

  Future<void> askWithoutSummary(
    WidgetTester tester,
    String name,
    Map<String, dynamic> args,
  ) async {
    await pumpChat(tester);
    backend.geminiHandler = (body) {
      if (body.containsKey('tools')) {
        return FakeBackend.geminiCall(name, args);
      }
      throw FakeHttpError(503);
    };

    await tester.enterText(find.byType(TextField), 'Do it');
    await tester.tap(find.byTooltip('Send message'));
    await settle(tester, frames: 20);
  }

  testWidgets('a failed follow-up still confirms a completed action',
      (tester) async {
    await withFakeHttp(() async {
      await askWithoutSummary(tester, 'query_tasks', {});

      expect(
          find.text('Done! Your request has been completed.'), findsOneWidget);
    });
  });

  testWidgets('a failed follow-up does not claim a failed action succeeded',
      (tester) async {
    await withFakeHttp(() async {
      await askWithoutSummary(
          tester, 'modify_item', {'item_type': 'task', 'item_id': 'x'});

      expect(find.text('Done! Your request has been completed.'), findsNothing);
      expect(
        find.text(
            'Sorry, I encountered an error while processing your request.'),
        findsOneWidget,
      );
    });
  });
}
