import 'dart:async';

import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

/// [PostgrestTransformBuilder] is a [Future]. A mock of that type does not
/// Complete when awaited, so the ticket refresh uses a future that does.
class _TicketRow extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  _TicketRow(this.value);

  final Map<String, dynamic>? value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    return Future<Map<String, dynamic>?>.value(value).then(
      onValue,
      onError: onError,
    );
  }
}

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late MockGoTrueClient auth;
  late MockQueryBuilder query;
  late MockFilterBuilder filter;
  late SupabaseService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    auth = MockGoTrueClient();
    query = MockQueryBuilder();
    filter = MockFilterBuilder();
    service = SupabaseService.withClient(client);

    when(() => client.functions).thenReturn(functions);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(
      const User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: null,
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    when(() => client.from('tickets')).thenAnswer((_) => query);
    when(() => query.select()).thenAnswer((_) => filter);
    when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
  });

  test('does not call GitHub sync before Supabase is initialized', () async {
    final result = await SupabaseService().syncTicketToGithub('ticket-1');

    expect(result['success'], isFalse);
    expect(result['error'], 'Supabase is not initialized');
  });

  test('sends the ticket id and returns the refreshed ticket', () async {
    when(
      () => functions.invoke(
        'github-sync',
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => FunctionResponse(
        status: 200,
        data: {'synced': true},
      ),
    );
    when(() => filter.maybeSingle()).thenAnswer(
      (_) => _TicketRow({'id': 'ticket-1', 'github_sync_status': 'synced'}),
    );

    final result = await service.syncTicketToGithub('ticket-1');

    expect(result['success'], isTrue);
    expect(result['status'], 200);
    expect(
        result['ticket'], {'id': 'ticket-1', 'github_sync_status': 'synced'});
    verify(
      () => functions.invoke(
        'github-sync',
        body: {'ticket_id': 'ticket-1'},
      ),
    ).called(1);
  });

  test('maps a function exception into a failed sync result', () async {
    when(
      () => functions.invoke(
        'github-sync',
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const FunctionException(
        status: 502,
        details: {'error': 'GitHub unavailable'},
      ),
    );
    when(() => filter.maybeSingle()).thenAnswer(
      (_) => _TicketRow({'id': 'ticket-1', 'github_sync_status': 'failed'}),
    );

    final result = await service.syncTicketToGithub('ticket-1');

    expect(result['success'], isFalse);
    expect(result['status'], 502);
    expect(result['error'], 'GitHub unavailable');
    expect(result['ticket']['github_sync_status'], 'failed');
  });

  test('returns a failure when the function call cannot be made', () async {
    when(
      () => functions.invoke(
        any(),
        body: any(named: 'body'),
      ),
    ).thenThrow(Exception('network down'));

    final result = await service.syncTicketToGithub('ticket-1');

    expect(result['success'], isFalse);
    expect(result['error'], contains('network down'));
  });
}
