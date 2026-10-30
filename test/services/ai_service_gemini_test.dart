import 'dart:async';
import 'dart:convert';

import 'package:ell_ena/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/test_harness.dart';

const _geminiPath = '/v1beta/models/gemini-2.5-flash:generateContent';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  final ai = AIService();

  /// The JSON bodies sent to Gemini, oldest first.
  List<Map<String, dynamic>> geminiRequests() => [
        for (final body in backend.bodiesFor('POST', _geminiPath))
          Map<String, dynamic>.from(body as Map),
      ];

  String systemText(Map<String, dynamic> request) =>
      (request['contents'] as List).first['parts'][0]['text'] as String;

  void stubRetrieval(List<Map<String, dynamic>> rows) {
    backend.rpcs['queue_embedding'] = (_) => 42;
    backend.rpcs['search_rag_by_resp_id'] = (body) {
      expect(body['resp_id'], 42);
      return rows;
    };
  }

  group('generateChatResponse', () {
    test('initialises lazily and returns a plain reply', () async {
      backend.geminiHandler = (_) => FakeBackend.geminiText('Hi Ada!');

      final reply = await withFakeHttp(() => ai.generateChatResponse(
            'hello',
            const [],
            const [],
            retrieveContext: false,
          ));

      expect(ai.isInitialized, isTrue);
      expect(reply, {'type': 'message', 'content': 'Hi Ada!'});
      final request = geminiRequests().single;
      expect((request['tools'] as List).single['functionDeclarations'],
          hasLength(6));
      expect(request['generationConfig'], {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      });
      final contents = request['contents'] as List;
      expect(contents.last, {
        'role': 'user',
        'parts': [
          {'text': 'hello'}
        ],
      });
    });

    test('puts retrieved workspace context and history in the prompt',
        () async {
      stubRetrieval([
        {
          'entity_type': 'task',
          'entity_id': 'secret-uuid',
          'title': 'Fix login',
          'status': 'in_progress',
          'similarity': 0.9,
        },
        {'entity_type': 'ticket', 'title': 'Too far', 'similarity': 0.1},
      ]);

      await withFakeHttp(() => ai.generateChatResponse(
            'what about login?',
            const [
              {'role': 'user', 'content': 'earlier question'},
              {'role': 'assistant', 'content': 'earlier answer'},
            ],
            const [
              {'id': 'user-2', 'full_name': 'Bob', 'role': 'member'}
            ],
          ));

      expect(backend.bodiesFor('POST', '/rest/v1/rpc/queue_embedding').single,
          {'query_text': 'what about login?'});
      final request = geminiRequests().single;
      final system = systemText(request);
      expect(system, contains('TASK\nTitle: Fix login\nStatus: In Progress'));
      expect(system, isNot(contains('Too far')));
      expect(system, isNot(contains('secret-uuid')));
      expect(system, contains('- Bob (member)'));
      final roles =
          (request['contents'] as List).map((c) => c['role']).toList();
      expect(roles, ['model', 'user', 'model', 'user']);
    });

    test('tells Gemini when retrieval failed', () async {
      backend.rpcs['queue_embedding'] = (_) => throw FakeHttpError(500);

      await withFakeHttp(
          () => ai.generateChatResponse('anything', const [], const []));

      expect(systemText(geminiRequests().single),
          contains('Workspace retrieval was unavailable'));
    });

    test('uses caller context when retrieval is skipped', () async {
      await withFakeHttp(() => ai.generateChatResponse(
            'q',
            const [],
            const [],
            ragContext: 'Relevant workspace context:\nCUSTOM BLOCK',
            retrieveContext: false,
          ));

      expect(systemText(geminiRequests().single), contains('CUSTOM BLOCK'));
      expect(backend.log, isNot(contains('POST /rest/v1/rpc/queue_embedding')));
    });

    test('returns tool calls with their arguments and raw response', () async {
      backend.geminiHandler = (_) => FakeBackend.geminiCall(
          'create_task', {'title': 'Write report', 'due_date': '2026-11-01'});

      final reply = await withFakeHttp(() => ai.generateChatResponse(
          'make a task', const [], const [],
          retrieveContext: false));

      expect(reply['type'], 'function_call');
      expect(reply['function_name'], 'create_task');
      expect(reply['arguments'],
          {'title': 'Write report', 'due_date': '2026-11-01'});
      final raw = jsonDecode(reply['raw_response'] as String) as Map;
      expect(raw['candidates'], isNotEmpty);
    });

    test('a candidate without text becomes an empty message', () async {
      backend.geminiHandler = (_) => {
            'candidates': [
              {
                'content': {
                  'parts': [<String, dynamic>{}]
                }
              }
            ]
          };

      final reply = await withFakeHttp(() => ai.generateChatResponse(
          'q', const [], const [],
          retrieveContext: false));

      expect(reply, {'type': 'message', 'content': ''});
    });

    test('reports no candidates, HTTP errors, and malformed replies', () async {
      Future<Map<String, dynamic>> ask() =>
          withFakeHttp(() => ai.generateChatResponse('q', const [], const [],
              retrieveContext: false));

      backend.geminiHandler = (_) => {'candidates': []};
      expect(
          await ask(), {'type': 'error', 'content': 'No response generated'});

      backend.geminiHandler = (_) => throw FakeHttpError(429);
      final limited = await ask();
      expect(limited['type'], 'error');
      expect(limited['content'], startsWith('Sorry'));

      backend.geminiHandler = (_) => {'candidates': 'not a list'};
      final malformed = await ask();
      expect(malformed['type'], 'error');
      expect(malformed['content'], startsWith('Sorry'));
    });
  });

  group('handleToolResponse', () {
    test('sends the call and its result back and returns the summary',
        () async {
      backend.geminiHandler = (_) => FakeBackend.geminiText('Task created.');

      final text = await withFakeHttp(() => ai.handleToolResponse(
            functionName: 'create_task',
            arguments: {'title': 'Report'},
            rawResponse: '{}',
            result: {'success': true},
            ragContext: 'Relevant workspace context:\nPRIOR',
          ));

      expect(text, 'Task created.');
      final request = geminiRequests().single;
      expect(request['generationConfig'], {
        'temperature': 0.7,
        'maxOutputTokens': 512,
      });
      final contents = request['contents'] as List;
      expect(contents, hasLength(4));
      expect(systemText(request), contains('PRIOR'));
      expect(contents[1]['parts'][0]['text'], "I'd like to create task");
      expect(contents[2]['parts'][0]['functionCall'], {
        'name': 'create_task',
        'args': {'title': 'Report'}
      });
      expect(contents[3]['parts'][0]['functionResponse'], {
        'name': 'create_task',
        'response': {
          'content': {'success': true}
        },
      });
    });

    test('returns no summary when Gemini has none', () async {
      Future<String?> respond({String raw = '{}'}) =>
          withFakeHttp(() => ai.handleToolResponse(
                functionName: 'query_tasks',
                arguments: const {},
                rawResponse: raw,
                result: const {},
              ));

      backend.geminiHandler = (_) => {'candidates': []};
      expect(await respond(), isNull);

      backend.geminiHandler = (_) => {
            'candidates': [
              {
                'content': {
                  'parts': [<String, dynamic>{}]
                }
              }
            ]
          };
      expect(await respond(), isNull);

      backend.geminiHandler = (_) => throw FakeHttpError(500);
      expect(await respond(), isNull);

      expect(await respond(raw: 'not json'), isNull);
      expect(geminiRequests(), hasLength(3));
    });
  });

  group('timeouts', () {
    /// Gemini never answers.
    Future<T> withHangingGemini<T>(Future<T> Function() body) =>
        http.runWithClient(
          body,
          () => MockClient((_) => Completer<http.Response>().future),
        );

    setUp(() => ai.requestTimeout = const Duration(milliseconds: 20));
    tearDown(() => ai.requestTimeout = const Duration(seconds: 30));

    test('a chat request that hangs becomes an error reply', () async {
      final reply = await withHangingGemini(() => ai.generateChatResponse(
          'q', const [], const [],
          retrieveContext: false));

      expect(reply['type'], 'error');
      expect(reply['content'], startsWith('Sorry'));
    });

    test('a tool summary that hangs returns no summary', () async {
      final text = await withHangingGemini(() => ai.handleToolResponse(
            functionName: 'create_task',
            arguments: const {},
            rawResponse: '{}',
            result: const {'success': true},
          ));

      expect(text, isNull);
    });
  });

  group('meeting search', () {
    test('queues an embedding and returns the matching meetings', () async {
      backend.rpcs['queue_embedding'] = (_) => 7;
      backend.rpcs['search_meeting_summaries_by_resp_id'] = (body) => [
            {
              'title': 'Retro',
              'meeting_date': '2026-10-01',
              'similarity': 0.8,
              'debug_info': 'hnsw',
            },
            {'title': 'Plain', 'meeting_date': '2026-10-02'},
          ];

      final meetings = await ai.getRelevantMeetingSummaries('retro notes');

      expect(meetings.map((m) => m['title']), ['Retro', 'Plain']);
      expect(
        backend
            .bodiesFor(
                'POST', '/rest/v1/rpc/search_meeting_summaries_by_resp_id')
            .single,
        {'resp_id': 7, 'match_count': 2},
      );
    });

    test('returns nothing for odd answers or failures', () async {
      backend.rpcs['queue_embedding'] = (_) => 7;
      backend.rpcs['search_meeting_summaries_by_resp_id'] =
          (_) => {'not': 'a list'};
      expect(await ai.getRelevantMeetingSummaries('q'), isEmpty);

      backend.rpcs['queue_embedding'] = (_) => 'not an id';
      expect(await ai.getRelevantMeetingSummaries('q'), isEmpty);
    });
  });

  test('getRelevantRagResults returns plain maps of the ranked rows', () async {
    stubRetrieval([
      {
        'entity_type': 'meeting',
        'entity_id': 'm1',
        'title': 'Kickoff',
        'similarity': 0.75,
        'meeting_date': '2026-09-01T10:00:00Z',
      },
    ]);

    final rows = await ai.getRelevantRagResults('kickoff');

    expect(rows.single['entity_type'], 'meeting');
    expect(rows.single['entity_id'], 'm1');
    expect(rows.single['similarity'], 0.75);
    expect(rows.single['meeting_date'], '2026-09-01T10:00:00.000Z');
  });

  test('semantic retrieval reports an unexpected embedding id', () async {
    backend.rpcs['queue_embedding'] = (_) => 'not-an-int';

    final outcome = await ai.retrieveSemanticContext('anything');

    expect(outcome.errorMessage, 'Could not search workspace context.');
    expect(backend.log,
        isNot(contains('POST /rest/v1/rpc/search_rag_by_resp_id')));
  });

  test('initialize is idempotent once ready', () async {
    await ai.initialize();
    backend.log.clear();

    await ai.initialize();

    expect(ai.isInitialized, isTrue);
    expect(backend.log, isEmpty);
  });
}
