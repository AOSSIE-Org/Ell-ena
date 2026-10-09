import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/rag_retriever.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RagRetriever', () {
    test('maps rag_search rows into typed results', () async {
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') {
            expect(params?['query_text'], 'authentication issue');
            return 42;
          }
          if (functionName == 'search_rag_by_resp_id') {
            expect(params?['resp_id'], 42);
            expect(params?['match_count'], 5);
            return [
              {
                'entity_type': 'meeting',
                'entity_id': 'm-1',
                'title': 'Auth retro',
                'content': '{"overall_summary":"Discussed login bugs"}',
                'similarity': 0.91,
              },
              {
                'entity_type': 'ticket',
                'entity_id': 't-1',
                'title': 'Broken OAuth redirect',
                'content': 'Users cannot complete Google sign-in',
                'similarity': 0.84,
              },
            ];
          }
          fail('Unexpected RPC $functionName');
        },
      );

      final outcome = await retriever.retrieve('authentication issue');

      expect(outcome.status, RagRetrievalStatus.success);
      expect(outcome.results, hasLength(2));
      expect(outcome.results.first.entityType, RagEntityType.meeting);
      expect(outcome.results.first.entityId, 'm-1');
      expect(outcome.results.last.entityType, RagEntityType.ticket);
      expect(outcome.results.last.similarity, closeTo(0.84, 0.001));
    });

    test('returns empty when search finds nothing', () async {
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') return 1;
          if (functionName == 'search_rag_by_resp_id') return <dynamic>[];
          fail('Unexpected RPC $functionName');
        },
      );

      final outcome = await retriever.retrieve('unrelated query');

      expect(outcome.status, RagRetrievalStatus.empty);
      expect(outcome.results, isEmpty);
      expect(outcome.errorMessage, isNull);
    });

    test('returns a user-safe error when embedding/search fails', () async {
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          throw Exception('postgrest secret key leaked');
        },
      );

      final outcome = await retriever.retrieve('auth');

      expect(outcome.status, RagRetrievalStatus.error);
      expect(outcome.results, isEmpty);
      expect(outcome.errorMessage, 'Could not search workspace context.');
      expect(outcome.errorMessage, isNot(contains('secret')));
    });

    test('treats a blank query as empty retrieval', () async {
      var rpcCalls = 0;
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          rpcCalls += 1;
          return 1;
        },
      );

      final outcome = await retriever.retrieve('   ');

      expect(outcome.status, RagRetrievalStatus.empty);
      expect(rpcCalls, 0);
    });
  });
}
