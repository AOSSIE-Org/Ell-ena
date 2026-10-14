import 'dart:async';

import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// [SupabaseClient.rpc] returns a filter builder that is also a [Future].
class _RpcResult extends Fake implements PostgrestFilterBuilder<dynamic> {
  _RpcResult(this.value);

  final dynamic value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return Future<dynamic>.value(value).then(onValue, onError: onError);
  }
}

void main() {
  late MockSupabaseClient client;
  late AIService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockSupabaseClient();
    service = AIService.forTesting(SupabaseService.withClient(client));
  });

  test('queues an embedding and returns the matching meetings', () async {
    when(() => client.rpc('queue_embedding', params: any(named: 'params')))
        .thenAnswer((_) => _RpcResult(4));
    when(
      () => client.rpc(
        'search_meeting_summaries_by_resp_id',
        params: any(named: 'params'),
      ),
    ).thenAnswer(
      (_) => _RpcResult([
        {'title': 'Standup', 'meeting_date': '2026-10-01'},
      ]),
    );

    final meetings = await service.getRelevantMeetingSummaries('standup');

    expect(meetings, hasLength(1));
    expect(meetings.single['title'], 'Standup');
    final captured = verify(
      () => client.rpc(
        'search_meeting_summaries_by_resp_id',
        params: captureAny(named: 'params'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured['resp_id'], 4);
    expect(captured['match_count'], 2);
    verify(
      () => client.rpc(
        'queue_embedding',
        params: {'query_text': 'standup'},
      ),
    ).called(1);
  });

  test('returns an empty list when the search result is not a list', () async {
    when(() => client.rpc('queue_embedding', params: any(named: 'params')))
        .thenAnswer((_) => _RpcResult(1));
    when(
      () => client.rpc(
        'search_meeting_summaries_by_resp_id',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) => _RpcResult({'unexpected': true}));

    expect(await service.getRelevantMeetingSummaries('planning'), isEmpty);
  });

  test('returns an empty list when the database call fails', () async {
    when(() => client.rpc(any(), params: any(named: 'params')))
        .thenThrow(Exception('network down'));

    expect(await service.getRelevantMeetingSummaries('planning'), isEmpty);
  });
}
