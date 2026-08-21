import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/rag_retriever.dart';
import 'package:ell_ena/services/rag_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RagRetriever', () {
    test('maps rag_search rows including ranking metadata', () async {
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') {
            expect(params?['query_text'], 'authentication issue');
            return 42;
          }
          if (functionName == 'search_rag_by_resp_id') {
            expect(params?['resp_id'], 42);
            expect(params?['match_count'], 5);
            expect(params?['similarity_threshold'], 0.30);
            return [
              {
                'entity_type': 'meeting',
                'entity_id': 'm-1',
                'title': 'Auth retro',
                'content': '{"overall_summary":"Discussed login bugs"}',
                'similarity': 0.91,
                'meeting_date': '2026-08-01T10:00:00Z',
                'recency_score': 0.8,
                'urgency_score': 0.0,
                'final_score': 0.797,
              },
              {
                'entity_type': 'ticket',
                'entity_id': 't-1',
                'title': 'Broken OAuth redirect',
                'content': 'Users cannot complete Google sign-in',
                'similarity': 0.84,
                'priority': 'high',
                'status': 'open',
                'urgency_score': 1.0,
                'final_score': 0.788,
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
      expect(outcome.results.first.meetingDate, isNotNull);
      expect(outcome.results.last.priority, 'high');
      expect(outcome.results.last.similarity, closeTo(0.84, 0.001));
    });

    test('passes bounded candidate_count when provided', () async {
      final retriever = RagRetriever(
        matchCount: 3,
        similarityThreshold: 0.35,
        candidateCount: 12,
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') return 1;
          if (functionName == 'search_rag_by_resp_id') {
            expect(params?['match_count'], 3);
            expect(params?['similarity_threshold'], 0.35);
            expect(params?['candidate_count'], 12);
            return <dynamic>[];
          }
          fail('Unexpected RPC $functionName');
        },
      );

      await retriever.retrieve('auth');
    });

    test('clamps oversized candidate_count before RPC', () async {
      final retriever = RagRetriever(
        matchCount: 5,
        candidateCount: 999,
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') return 1;
          if (functionName == 'search_rag_by_resp_id') {
            expect(
              params?['candidate_count'],
              RagScoring.maxCandidateCount,
            );
            return <dynamic>[];
          }
          fail('Unexpected RPC $functionName');
        },
      );

      await retriever.retrieve('auth');
    });

    test('filters weak matches below similarity threshold', () async {
      final retriever = RagRetriever(
        similarityThreshold: 0.30,
        rpc: (functionName, {params}) async {
          if (functionName == 'queue_embedding') return 1;
          return [
            {
              'entity_type': 'task',
              'entity_id': 'weak',
              'title': 'Weak match',
              'content': 'unrelated',
              'similarity': 0.12,
            },
            {
              'entity_type': 'task',
              'entity_id': 'strong',
              'title': 'Strong match',
              'content': 'auth',
              'similarity': 0.72,
            },
          ];
        },
      );

      final outcome = await retriever.retrieve('auth');
      expect(outcome.results, hasLength(1));
      expect(outcome.results.single.entityId, 'strong');
    });

    test('parses legacy rows without ranking metadata', () {
      final result = RagResult.fromMap({
        'entity_type': 'task',
        'entity_id': 'legacy',
        'title': 'Old shape',
        'content': 'desc',
        'similarity': 0.5,
      });
      expect(result.priority, isNull);
      expect(result.finalScore, isNull);
      expect(result.similarity, 0.5);
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
    });

    test('returns a user-safe error when embedding/search fails', () async {
      final retriever = RagRetriever(
        rpc: (functionName, {params}) async {
          throw Exception('postgrest secret key leaked');
        },
      );

      final outcome = await retriever.retrieve('auth');

      expect(outcome.status, RagRetrievalStatus.error);
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

  group('RagScoring', () {
    final now = DateTime(2026, 8, 22, 12);

    test('recency decays with age', () {
      final fresh = RagScoring.recencyScore(now, now: now);
      final old = RagScoring.recencyScore(
        now.subtract(const Duration(days: 60)),
        now: now,
      );
      expect(fresh, greaterThan(old));
      expect(fresh, closeTo(1.0, 0.01));
    });

    test('future dates do not exceed recency of 1.0', () {
      final future = RagScoring.recencyScore(
        now.add(const Duration(days: 5)),
        now: now,
      );
      expect(future, closeTo(1.0, 0.01));
    });

    test('null reference uses now and scores near 1.0', () {
      expect(RagScoring.recencyScore(null, now: now), closeTo(1.0, 0.01));
    });

    test('completed tasks get no urgency boost', () {
      expect(
        RagScoring.taskUrgency(
          status: 'completed',
          dueDate: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        0.0,
      );
    });

    test('overdue active task has highest urgency', () {
      final overdue = RagScoring.taskUrgency(
        status: 'todo',
        dueDate: now.subtract(const Duration(days: 1)),
        now: now,
      );
      final dueSoon = RagScoring.taskUrgency(
        status: 'todo',
        dueDate: now.add(const Duration(days: 2)),
        now: now,
      );
      final noDue = RagScoring.taskUrgency(status: 'todo', now: now);
      expect(overdue, 1.0);
      expect(dueSoon, 0.85);
      expect(noDue, 0.30);
      expect(overdue, greaterThan(dueSoon));
      expect(dueSoon, greaterThan(noDue));
    });

    test('ticket priority and resolved status', () {
      expect(
        RagScoring.ticketUrgency(priority: 'high', status: 'open'),
        1.0,
      );
      expect(
        RagScoring.ticketUrgency(priority: 'medium', status: 'in_progress'),
        0.50,
      );
      expect(
        RagScoring.ticketUrgency(priority: 'low', status: 'open'),
        0.20,
      );
      expect(
        RagScoring.ticketUrgency(priority: 'high', status: 'resolved'),
        0.0,
      );
    });

    test('unrelated high urgency cannot beat strong semantic match', () {
      final relevant = RagScoring.finalScore(
        similarity: 0.85,
        recency: 0.5,
        urgency: 0.1,
      );
      final unrelatedUrgent = RagScoring.finalScore(
        similarity: 0.20,
        recency: 1.0,
        urgency: 1.0,
      );
      expect(RagScoring.passesSimilarityFloor(0.20), isFalse);
      expect(relevant, greaterThan(unrelatedUrgent));
    });

    test('semantic weight dominates final score', () {
      expect(RagScoring.semanticWeight, greaterThan(RagScoring.recencyWeight));
      expect(RagScoring.semanticWeight, greaterThan(RagScoring.urgencyWeight));
    });

    test('candidate and match count bounds', () {
      expect(RagScoring.boundMatchCount(0), 1);
      expect(RagScoring.boundMatchCount(100), RagScoring.maxMatchCount);
      expect(RagScoring.boundCandidateCount(null, 5), 15);
      expect(RagScoring.boundCandidateCount(2, 5), 5);
      expect(
        RagScoring.boundCandidateCount(999, 5),
        RagScoring.maxCandidateCount,
      );
    });
  });
}
