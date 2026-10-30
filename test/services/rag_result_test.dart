import 'package:ell_ena/models/rag_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RagEntityType', () {
    test('parses known kinds and labels them back', () {
      for (final type in RagEntityType.values) {
        expect(RagEntityType.fromString(type.label), type);
      }
      expect(RagEntityType.fromString(null), RagEntityType.unknown);
      expect(RagEntityType.fromString('Meeting'), RagEntityType.unknown);
    });
  });

  group('RagResult.fromMap', () {
    test('reads every column, accepting numeric strings and DateTimes', () {
      final due = DateTime.utc(2026, 11, 1);
      final result = RagResult.fromMap({
        'entity_type': 'task',
        'entity_id': 42,
        'title': 'Write docs',
        'content': 'all of them',
        'similarity': '0.75',
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-02T00:00:00Z',
        'meeting_date': null,
        'due_date': due,
        'priority': 'high',
        'status': 'todo',
        'recency_score': 1,
        'urgency_score': 0.5,
        'final_score': '0.8',
      });

      expect(result.entityType, RagEntityType.task);
      expect(result.entityId, '42');
      expect(result.similarity, 0.75);
      expect(result.createdAt, DateTime.utc(2026, 10, 1));
      expect(result.meetingDate, isNull);
      expect(result.dueDate, same(due));
      expect(result.recencyScore, 1.0);
      expect(result.finalScore, 0.8);
    });

    test('falls back for missing and unparseable values', () {
      final result = RagResult.fromMap({
        'similarity': 'high',
        'created_at': 'yesterday',
        'urgency_score': true,
      });

      expect(result.entityType, RagEntityType.unknown);
      expect(result.entityId, '');
      expect(result.title, 'Untitled');
      expect(result.similarity, isNull);
      expect(result.createdAt, isNull);
      expect(result.urgencyScore, isNull);
    });

    test('toMap writes the same keys back', () {
      final map = {
        'entity_type': 'ticket',
        'entity_id': 'k1',
        'title': 'Crash',
        'content': null,
        'similarity': 0.5,
        'created_at': '2026-10-01T00:00:00.000Z',
        'updated_at': null,
        'meeting_date': null,
        'due_date': null,
        'priority': 'low',
        'status': 'open',
        'recency_score': null,
        'urgency_score': null,
        'final_score': null,
      };

      expect(RagResult.fromMap(map).toMap(), map);
    });
  });

  group('RagRetrievalOutcome', () {
    RagResult withSimilarity(double? s) => RagResult(
        entityType: RagEntityType.task,
        entityId: '$s',
        title: 't',
        similarity: s);

    test('named states carry their status', () {
      // Not const: built at run time, as ChatController does.
      final states = [
        RagRetrievalOutcome.idle(),
        RagRetrievalOutcome.loading(),
      ];
      expect(states.map((s) => s.status),
          [RagRetrievalStatus.idle, RagRetrievalStatus.loading]);
      expect(states.every((s) => !s.hasResults), isTrue);
      expect(const RagRetrievalOutcome.empty().hasResults, isFalse);
      final error = const RagRetrievalOutcome.error('nope');
      expect(error.status, RagRetrievalStatus.error);
      expect(error.errorMessage, 'nope');
    });

    test('filteredBySimilarity keeps unscored rows and rows at the floor', () {
      final outcome = RagRetrievalOutcome.success([
        withSimilarity(0.2),
        withSimilarity(0.3),
        withSimilarity(null),
      ]).filteredBySimilarity(threshold: 0.3);

      expect(outcome.status, RagRetrievalStatus.success);
      expect(outcome.results.map((r) => r.similarity), [0.3, null]);
    });

    test('filteredBySimilarity empties when nothing passes', () {
      final outcome = RagRetrievalOutcome.success([withSimilarity(0.1)])
          .filteredBySimilarity();

      expect(outcome.status, RagRetrievalStatus.empty);
    });

    test('filtering an outcome without results returns it unchanged', () {
      const error = RagRetrievalOutcome.error('x');

      expect(error.filteredBySimilarity(), same(error));
    });
  });
}
