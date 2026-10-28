import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/test_harness.dart';
import 'supabase_service_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Map<String, dynamic> meeting(String id, String date) => {
        'id': id,
        'title': 'Meeting $id',
        'meeting_date': date,
        'meeting_url': 'https://meet.example.com/$id',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
      };

  group('getMeetings', () {
    test('returns team meetings in date order and streams them', () async {
      backend.table('meetings').addAll([
        meeting('late', '2026-12-01T10:00:00Z'),
        meeting('early', '2026-11-01T10:00:00Z'),
        {...meeting('foreign', '2026-11-15T10:00:00Z'), 'team_id': 'x'},
        {...meeting('anon', '2026-11-20T10:00:00Z'), 'created_by': null},
      ]);
      final service = await signedInService();
      final streamed = service.meetingsStream.first;

      final meetings = await service.getMeetings();

      expect(meetings.map((m) => m['id']), ['early', 'anon', 'late']);
      expect(meetings.first['creator']['full_name'], 'Ada');
      expect(meetings[1].containsKey('creator'), isFalse);
      expect(await streamed, meetings);
    });

    test('returns nothing without a team or when the query fails', () async {
      backend.table('meetings').add(meeting('m', '2026-11-01T10:00:00Z'));
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['meetings'] = 500;
      expect(await service.getMeetings(), isEmpty);

      backend.table('users').first['team_id'] = null;
      expect(await (await signedInService()).getMeetings(), isEmpty);
    });

    test('stops streaming after dispose', () async {
      backend.table('meetings').add(meeting('m', '2026-11-01T10:00:00Z'));
      final service = await signedInService();
      service.dispose();
      service.dispose();

      expect(await service.getMeetings(), hasLength(1));
      expect(await service.meetingsStream.isEmpty, isTrue);
      expect(await service.tasksStream.isEmpty, isTrue);
      expect(await service.ticketsStream.isEmpty, isTrue);
    });
  });

  group('createMeeting', () {
    test('inserts the meeting for the team and refreshes', () async {
      final service = await signedInService();
      final date = DateTime.utc(2026, 11, 3, 15);

      final result = await service.createMeeting(
        title: 'Retro',
        description: 'Sprint 12',
        meetingDate: date,
        meetingUrl: 'https://meet.example.com/retro',
        durationMinutes: 30,
      );

      expect(result['success'], isTrue);
      expect(backend.bodiesFor('POST', '/rest/v1/meetings').single, {
        'title': 'Retro',
        'description': 'Sprint 12',
        'meeting_date': date.toIso8601String(),
        'meeting_url': 'https://meet.example.com/retro',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'duration_minutes': 30,
      });
      expect(result['meeting']['title'], 'Retro');
      expect(backend.log.last, 'GET /rest/v1/users');
      expect(backend.log, contains('GET /rest/v1/meetings'));
    });

    test('refuses users without a team, empty inserts, and errors', () async {
      backend.table('users').first['team_id'] = null;
      final teamless = await signedInService();
      expect(
        (await teamless.createMeeting(
            title: 'x', meetingDate: DateTime(2026)))['error'],
        'User not associated with a team',
      );

      backend.table('users').first['team_id'] = FakeBackend.teamId;
      final empty = await signedInService(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/meetings')
            ? http.Response('[]', 201)
            : null,
      );
      expect(
        await empty.createMeeting(title: 'x', meetingDate: DateTime(2026)),
        {'success': false, 'error': 'Failed to create meeting'},
      );

      final failing = await signedInService();
      await failing.getCurrentUserProfile();
      backend.failures['meetings'] = 500;
      expect(
        (await failing.createMeeting(
            title: 'x', meetingDate: DateTime(2026)))['success'],
        isFalse,
      );
    });
  });

  group('getMeetingDetails', () {
    test('adds the creator', () async {
      backend.table('meetings').add(meeting('m1', '2026-11-01T10:00:00Z'));
      final service = await signedInService();

      final details = await service.getMeetingDetails('m1');

      expect(details!['title'], 'Meeting m1');
      expect(details['creator']['full_name'], 'Ada');
    });

    test('leaves the creator empty when unknown and returns null if missing',
        () async {
      backend
          .table('meetings')
          .add({...meeting('m1', '2026-11-01T10:00:00Z'), 'created_by': null});
      final service = await signedInService();

      expect((await service.getMeetingDetails('m1'))!['creator'], isNull);
      expect(await service.getMeetingDetails('missing'), isNull);
    });
  });

  group('updateMeeting', () {
    test('patches the base fields plus any optional ones given', () async {
      backend.table('meetings').add(meeting('m1', '2026-11-01T10:00:00Z'));
      final service = await signedInService();
      final date = DateTime.utc(2026, 11, 5, 9);

      final result = await service.updateMeeting(
        meetingId: 'm1',
        title: 'Renamed',
        description: 'New agenda',
        meetingDate: date,
        meetingUrl: 'https://meet.example.com/new',
        transcription: 'hello',
        aiSummary: '{"overall_summary":"ok"}',
        durationMinutes: 45,
      );

      expect(result['success'], isTrue);
      final body =
          backend.bodiesFor('PATCH', '/rest/v1/meetings').single as Map;
      expect(body['title'], 'Renamed');
      expect(body['meeting_date'], date.toIso8601String());
      expect(body['transcription'], 'hello');
      expect(body['ai_summary'], '{"overall_summary":"ok"}');
      expect(body['duration_minutes'], 45);
      expect(DateTime.tryParse(body['updated_at'] as String), isNotNull);
      expect(backend.table('meetings').single['title'], 'Renamed');
      expect(result['meeting']['title'], 'Renamed');
    });

    test('omits optional fields that were not given', () async {
      backend.table('meetings').add(meeting('m1', '2026-11-01T10:00:00Z'));
      final service = await signedInService();

      await service.updateMeeting(
          meetingId: 'm1', title: 'T', meetingDate: DateTime(2026));

      final body =
          backend.bodiesFor('PATCH', '/rest/v1/meetings').single as Map;
      expect(
        body.keys,
        unorderedEquals([
          'title',
          'description',
          'meeting_date',
          'meeting_url',
          'updated_at'
        ]),
      );
    });

    test('reports a missing meeting and backend errors', () async {
      final service = await signedInService();
      expect(
        await service.updateMeeting(
            meetingId: 'missing', title: 'T', meetingDate: DateTime(2026)),
        {'success': false, 'error': 'Failed to update meeting'},
      );

      backend.failures['meetings'] = 500;
      expect(
        (await service.updateMeeting(
            meetingId: 'm',
            title: 'T',
            meetingDate: DateTime(2026)))['success'],
        isFalse,
      );
    });
  });

  group('deleteMeeting', () {
    test('removes the meeting and refreshes', () async {
      backend.table('meetings').add(meeting('m1', '2026-11-01T10:00:00Z'));
      final service = await signedInService();

      expect(await service.deleteMeeting('m1'), {'success': true});
      expect(backend.table('meetings'), isEmpty);
      expect(backend.log, contains('GET /rest/v1/meetings'));
    });

    test('reports backend errors', () async {
      final service = await signedInService();
      backend.failures['meetings'] = 500;

      expect((await service.deleteMeeting('m1'))['success'], isFalse);
    });
  });

  group('startBot', () {
    test('sends the meeting to start-bot and merges its answer', () async {
      backend.functions['start-bot'] = (_) => {'bot_id': 'b1'};
      final service = await signedInService();

      final result = await service.startBot(
        meetingId: 'm1',
        meetingUrl: 'https://meet.example.com/m1',
      );

      expect(result, {'success': true, 'status': 200, 'bot_id': 'b1'});
      expect(backend.functionBodies('start-bot').single, {
        'meeting_id': 'm1',
        'meeting_url': 'https://meet.example.com/m1',
      });
    });

    test('uses the error from a JSON or text failure body', () async {
      backend.functions['start-bot'] =
          (_) => throw FakeHttpError(400, {'error': 'Bad meeting URL'});
      final service = await signedInService();
      expect(
        await service.startBot(meetingId: 'm', meetingUrl: 'u'),
        {'success': false, 'status': 400, 'error': 'Bad meeting URL'},
      );

      final text = await signedInService(
        intercept: (r) => r.url.path.endsWith('/start-bot')
            ? http.Response('Vexa unavailable', 503,
                headers: {'content-type': 'text/plain'})
            : null,
      );
      expect(
        await text.startBot(meetingId: 'm', meetingUrl: 'u'),
        {'success': false, 'status': 503, 'error': 'Vexa unavailable'},
      );
    });

    test('falls back to a generic message', () async {
      backend.functions['start-bot'] =
          (_) => throw FakeHttpError(500, {'detail': 'x'});
      final service = await signedInService();

      expect(
        await service.startBot(meetingId: 'm', meetingUrl: 'u'),
        {
          'success': false,
          'status': 500,
          'error': 'Request to start-bot failed'
        },
      );
    });

    test('reports transport failures', () async {
      final service = await signedInService(
        intercept: (r) => r.url.path.endsWith('/start-bot')
            ? throw http.ClientException('offline')
            : null,
      );

      final result = await service.startBot(meetingId: 'm', meetingUrl: 'u');

      expect(result['success'], isFalse);
      expect(result['error'], contains('offline'));
    });

    test('accepts any 2xx answer, with or without a JSON body', () async {
      final service = await signedInService(
        intercept: (r) => r.url.path.endsWith('/start-bot')
            ? http.Response('{"queued":true}', 202)
            : null,
      );
      final ok = await service.startBot(meetingId: 'm', meetingUrl: 'u');
      expect(ok['success'], isTrue);
      expect(ok['queued'], isTrue);

      final plain = await signedInService(
        intercept: (r) => r.url.path.endsWith('/start-bot')
            ? http.Response('done', 200,
                headers: {'content-type': 'text/plain'})
            : null,
      );
      expect(await plain.startBot(meetingId: 'm', meetingUrl: 'u'),
          {'success': true, 'status': 200});
    });
  });

  group('fetchAndProcessTranscript', () {
    setUp(() {
      backend.table('meetings').add(meeting('m1', '2026-11-01T10:00:00Z'));
    });

    test('runs fetch, summarize, and embed, then reloads the meeting',
        () async {
      final calls = <String>[];
      for (final name in [
        'fetch-transcript',
        'summarize-transcription',
        'generate-embeddings',
      ]) {
        backend.functions[name] = (body) {
          calls.add(name);
          expect(body['meeting_id'], 'm1');
          return {'ok': true};
        };
      }
      final service = await signedInService();

      final result = await service.fetchAndProcessTranscript(
        meetingId: 'm1',
        meetingUrl: 'https://meet.example.com/m1',
      );

      expect(calls, [
        'fetch-transcript',
        'summarize-transcription',
        'generate-embeddings'
      ]);
      expect(backend.functionBodies('fetch-transcript').single, {
        'meeting_id': 'm1',
        'meeting_url': 'https://meet.example.com/m1',
      });
      expect(result['success'], isTrue);
      expect(result['status'], 200);
      expect(result['meeting']['id'], 'm1');
    });

    test('stops at a failed fetch', () async {
      backend.functions['fetch-transcript'] =
          (_) => throw FakeHttpError(404, {'error': 'No transcript yet'});
      final service = await signedInService();

      final result = await service.fetchAndProcessTranscript(
          meetingId: 'm1', meetingUrl: 'u');

      expect(result['success'], isFalse);
      expect(result['error'], 'No transcript yet');
      expect(result['meeting']['id'], 'm1');
      expect(backend.functionBodies('summarize-transcription'), isEmpty);
    });

    test('stops at a failed summary', () async {
      backend.functions['fetch-transcript'] = (_) => {'ok': true};
      backend.functions['summarize-transcription'] =
          (_) => throw FakeHttpError(500, {'error': 'Gemini quota'});
      final service = await signedInService();

      final result = await service.fetchAndProcessTranscript(
          meetingId: 'm1', meetingUrl: 'u');

      expect(result['success'], isFalse);
      expect(result['error'], 'Gemini quota');
      expect(backend.functionBodies('generate-embeddings'), isEmpty);
    });

    test('stops at failed embeddings', () async {
      backend.functions['fetch-transcript'] = (_) => {'ok': true};
      backend.functions['summarize-transcription'] = (_) => {'ok': true};
      backend.functions['generate-embeddings'] =
          (_) => throw FakeHttpError(500, {'error': 'Embedding failed'});
      final service = await signedInService();

      final result = await service.fetchAndProcessTranscript(
          meetingId: 'm1', meetingUrl: 'u');

      expect(result['success'], isFalse);
      expect(result['error'], 'Embedding failed');
      expect(result['meeting']['id'], 'm1');
    });

    test('omits the meeting when it cannot be reloaded', () async {
      backend.functions['fetch-transcript'] =
          (_) => throw FakeHttpError(500, {'error': 'x'});
      final service = await signedInService();

      final result = await service.fetchAndProcessTranscript(
          meetingId: 'missing', meetingUrl: 'u');

      expect(result.containsKey('meeting'), isFalse);
    });
  });
}
