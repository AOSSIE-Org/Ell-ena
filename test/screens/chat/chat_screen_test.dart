import 'package:ell_ena/models/chat_message.dart';
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/chat_controller.dart';
import 'package:ell_ena/screens/chat/chat_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_detail_screen.dart';
import 'package:ell_ena/screens/tasks/task_detail_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_detail_screen.dart';
import 'package:ell_ena/widgets/chat/context_insights_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'speech_mock.dart';

const _geminiPath = '/v1beta/models/gemini-2.5-flash:generateContent';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() async {
    mockSpeech();
    await resetFakeSupabase();
  });

  Future<void> pumpChat(
    WidgetTester tester, {
    Size size = phoneSize,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(tester, const ChatScreen(), size: size, themeMode: themeMode);
    await settle(tester);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byTooltip('Send message'));
    await settle(tester);
  }

  ChatController chat(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ChatScreen)))
          .read(chatControllerProvider.notifier);

  /// Contents Gemini received in its most recent request.
  List<dynamic> lastGeminiContents() {
    final bodies = backend.bodiesFor('POST', _geminiPath);
    return (bodies.last as Map)['contents'] as List;
  }

  /// Meeting detail pages close themselves when the meeting is missing.
  void seedMeeting(String id) {
    backend.table('meetings').add({
      'id': id,
      'title': 'Seeded meeting',
      'team_id': FakeBackend.teamId,
      'created_by': FakeBackend.userId,
      'meeting_date': '2026-11-03T15:30:00',
    });
  }

  void seedRag() {
    seedMeeting('meeting-9');
    backend.rpcs['queue_embedding'] = (_) => 42;
    backend.rpcs['search_rag_by_resp_id'] = (body) {
      expect(body['resp_id'], 42);
      return [
        {
          'entity_type': 'task',
          'entity_id': 'task-9',
          'title': 'Prepare slides',
          'status': 'todo',
          'similarity': 0.91,
        },
        {
          'entity_type': 'ticket',
          'entity_id': 'ticket-9',
          'title': 'Crash on save',
          'status': 'open',
          'priority': 'high',
          'similarity': 0.88,
        },
        {
          'entity_type': 'meeting',
          'entity_id': 'meeting-9',
          'title': 'Design review',
          'content': 'Agreed on the new layout',
          'similarity': 0.8,
        },
      ];
    };
  }

  testWidgets('greets, then shows the user message and the reply',
      (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => FakeBackend.geminiText('Hi Ada!');
      await pumpChat(tester);

      expect(find.text('Chat with Ell-ena'), findsOneWidget);
      expect(
        find.text(
            "Hello! I'm Ell-ena, your AI assistant. How can I help you today?"),
        findsOneWidget,
      );

      await send(tester, 'Hello there');

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Hi Ada!'), findsOneWidget);
      // The input is cleared and the welcome is sent as history.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      final contents = lastGeminiContents();
      expect((contents.last as Map)['parts'][0]['text'], 'Hello there');
      expect(
        contents.any((c) =>
            (c as Map)['role'] == 'model' &&
            '${c['parts'][0]['text']}'.startsWith("Hello! I'm Ell-ena")),
        isTrue,
      );
    });
  });

  testWidgets('blank input and the keyboard action', (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => FakeBackend.geminiText('Got it');
      await pumpChat(tester, themeMode: ThemeMode.dark);

      await send(tester, '   ');
      expect(backend.bodiesFor('POST', _geminiPath), isEmpty);

      await tester.enterText(find.byType(TextField), 'From keyboard');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Got it'), findsOneWidget);
    });
  });

  testWidgets('sending is disabled while a reply is pending', (tester) async {
    await withFakeHttp(() async {
      await pumpChat(tester);
      chat(tester).setProcessing(true);
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);

      // The keyboard action is ignored too.
      await tester.enterText(find.byType(TextField), 'Too soon');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Too soon'), findsOneWidget); // still in the input
      expect(backend.bodiesFor('POST', _geminiPath), isEmpty);
    });
  });

  testWidgets('a Gemini error is shown as an apology', (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => throw FakeHttpError(500);
      await pumpChat(tester);

      await send(tester, 'Anything');

      expect(
        find.text(
            'Sorry, I encountered an error while processing your request.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a reply without text falls back to the generic apology',
      (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => {'candidates': []};
      await pumpChat(tester);

      await send(tester, 'Anything');

      // "No response generated" is the error content.
      expect(find.text('No response generated'), findsOneWidget);
    });
  });

  testWidgets('a malformed tool call is caught and apologised for',
      (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {'name': 'create_task', 'args': null}
                    }
                  ]
                }
              }
            ]
          };
      await pumpChat(tester);

      await send(tester, 'Make a task');

      expect(
        find.text('Sorry, I encountered an error. Please try again later.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('formats headers, bullets, dates and separators', (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => FakeBackend.geminiText([
            '*Weekly summary*',
            '• Shipped login',
            '📅 Monday, Nov 3',
            '🕒 10:00 AM',
            'Key *Points*:',
            '---',
            '',
            'Plain closing line',
          ].join('\n'));
      await pumpChat(tester, size: const Size(480, 1400));

      await send(tester, 'Summarise');

      final header = tester.widget<Text>(find.text('Weekly summary'));
      expect(header.style?.fontWeight, FontWeight.bold);
      expect(find.text('•'), findsOneWidget);
      expect(find.text('Shipped login'), findsOneWidget);
      final date = tester.widget<Text>(find.text('📅 Monday, Nov 3'));
      expect(date.style?.fontSize, 16);
      final time = tester.widget<Text>(find.text('🕒 10:00 AM'));
      expect(time.style?.fontSize, 14);
      expect(find.text('Key Points:'), findsOneWidget);
      expect(find.text('---'), findsNothing);
      expect(find.text('Plain closing line'), findsOneWidget);
    });
  });

  group('workspace context', () {
    testWidgets('phone: the context sheet lists matches and opens them',
        (tester) async {
      await withFakeHttp(() async {
        seedRag();
        backend.geminiHandler = (_) => FakeBackend.geminiText('Here you go');
        await pumpChat(tester);

        await send(tester, 'What is on my plate?');
        // The retrieved context is sent to Gemini.
        final system =
            '${(lastGeminiContents().first as Map)['parts'][0]['text']}';
        expect(system, contains('Prepare slides'));

        expect(find.byType(ContextInsightsPanel), findsNothing);
        await tester.tap(find.byTooltip('Context'));
        await settle(tester);
        expect(find.byType(ContextInsightsPanel), findsOneWidget);
        expect(find.text('Prepare slides'), findsOneWidget);
        expect(find.text('Crash on save'), findsOneWidget);

        await tester.tap(find.text('Prepare slides'));
        await settle(tester);
        expect(
          tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
          'task-9',
        );
      });
    });

    testWidgets('wide: the context panel sits beside the chat', (tester) async {
      await withFakeHttp(() async {
        seedRag();
        await pumpChat(tester, size: wideSize);

        expect(find.byTooltip('Context'), findsNothing);
        expect(find.byType(ContextInsightsPanel), findsOneWidget);
        await send(tester, 'Show tickets');

        await tester.tap(find.text('Crash on save'));
        await settle(tester);
        expect(
          tester
              .widget<TicketDetailScreen>(find.byType(TicketDetailScreen))
              .ticketId,
          'ticket-9',
        );
        Navigator.of(tester.element(find.byType(TicketDetailScreen))).pop();
        await tester.pump(const Duration(seconds: 1));
        await settle(tester);

        await tester.tap(find.text('Design review'));
        await settle(tester);
        expect(
          tester
              .widget<MeetingDetailScreen>(find.byType(MeetingDetailScreen))
              .meetingId,
          'meeting-9',
        );
      });
    });

    testWidgets('results without an id or a known type are not opened',
        (tester) async {
      await withFakeHttp(() async {
        await pumpChat(tester, size: wideSize);
        final onTap = tester
            .widget<ContextInsightsPanel>(find.byType(ContextInsightsPanel))
            .onResultTap!;

        onTap(const RagResult(
          entityType: RagEntityType.task,
          entityId: '',
          title: 'No id',
        ));
        await tester.pump();
        expect(
          find.text('Could not open this item. Details missing.'),
          findsOneWidget,
        );

        ScaffoldMessenger.of(tester.element(find.byType(ChatScreen)))
            .removeCurrentSnackBar();
        onTap(const RagResult(
          entityType: RagEntityType.unknown,
          entityId: 'x',
          title: 'Mystery',
        ));
        await tester.pump();
        expect(find.text('Could not open this item.'), findsOneWidget);
        expect(find.byType(TaskDetailScreen), findsNothing);
      });
    });
  });

  group('created item cards', () {
    Future<void> addCard(
      WidgetTester tester, {
      String? cardType,
      Map<String, dynamic>? cardData,
      String text = 'Card title',
    }) async {
      chat(tester).addMessage(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        isCard: true,
        cardType: cardType,
        cardData: cardData,
      ));
      await tester.pump();
    }

    testWidgets('meeting card shows its date and opens the meeting',
        (tester) async {
      await withFakeHttp(() async {
        seedMeeting('m-1');
        await pumpChat(tester);
        await addCard(
          tester,
          cardType: 'meeting',
          cardData: {
            'meeting': {'id': 'm-1', 'meeting_date': '2026-11-03T15:30:00'}
          },
          text: 'Sprint review',
        );

        expect(find.text('New Meeting'), findsOneWidget);
        expect(find.text('Nov 3, 2026 • 3:30 PM'), findsOneWidget);
        await tester.tap(find.text('View Meeting'));
        await settle(tester);
        expect(
          tester
              .widget<MeetingDetailScreen>(find.byType(MeetingDetailScreen))
              .meetingId,
          'm-1',
        );
      });
    });

    testWidgets('ticket and task cards open their items', (tester) async {
      await withFakeHttp(() async {
        await pumpChat(tester);
        await addCard(tester, cardType: 'ticket', cardData: {
          'ticket': {'id': 'k-1'}
        });
        expect(find.text('Created just now'), findsOneWidget);
        await tester.tap(find.text('View Ticket'));
        await settle(tester);
        expect(find.byType(TicketDetailScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(TicketDetailScreen))).pop();
        await tester.pump(const Duration(seconds: 1));
        await settle(tester);

        await addCard(tester, cardType: 'task', cardData: {
          'task': {'id': 't-1'}
        });
        await tester.tap(find.text('View Task'));
        await settle(tester);
        expect(find.byType(TaskDetailScreen), findsOneWidget);
      });
    });

    testWidgets('cards without data cannot be opened', (tester) async {
      await withFakeHttp(() async {
        await pumpChat(tester, size: const Size(480, 1400));
        // A meeting card with an unparseable date shows no date.
        await addCard(tester, cardType: 'meeting', cardData: {
          'meeting': {'meeting_date': 'soon'}
        });
        await addCard(tester, cardType: 'generic', text: 'Other');
        await addCard(tester, text: 'Untyped');

        expect(find.text('View Generic'), findsOneWidget);
        expect(find.text('View Item'), findsOneWidget);
        expect(find.text('Item Created'), findsNWidgets(2));

        await tester.tap(find.text('View Item'));
        await tester.pump();
        expect(
          find.text('Could not navigate to the item. Details missing.'),
          findsOneWidget,
        );
      });
    });
  });

  test('capitalize upper-cases the first letter only', () {
    expect('meeting'.capitalize(), 'Meeting');
    expect('aBC'.capitalize(), 'ABC');
    expect('x'.capitalize(), 'X');
  });
}
