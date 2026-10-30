import 'dart:convert';
import 'dart:math';

import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/meeting_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/property.dart';

Map<String, dynamic> _summary(Random r) => {
      if (r.nextBool())
        'key_discussion_points': Gens.listOf(Gens.word(), maxLength: 4)(r),
      if (r.nextBool())
        'important_decisions': Gens.listOf(Gens.word(), maxLength: 4)(r),
      if (r.nextBool())
        'action_items': Gens.listOf(
          (r) => <String, dynamic>{
            if (r.nextBool()) 'item': Gens.word()(r),
            if (r.nextBool()) 'owner': Gens.word()(r),
            if (r.nextBool()) 'deadline': Gens.word()(r),
          },
          maxLength: 3,
        )(r),
      if (r.nextBool())
        'follow_up_tasks': Gens.listOf(Gens.word(), maxLength: 3)(r),
      if (r.nextBool()) 'overall_summary': Gens.string()(r),
    };

void main() {
  group('MeetingFormatter', () {
    property<List<Object>>(
      'every summary entry appears as its own arrow line under a header',
      (r) => [Gens.word()(r), _summary(r)],
      (input) {
        final title = input[0] as String;
        final summary = input[1] as Map<String, dynamic>;
        final text = MeetingFormatter.formatMeetingSummary(
            title: title, date: 'D', summary: summary);
        final lines = text.split('\n');

        expect(lines.first, '📅 *$title*');
        for (final key in [
          'key_discussion_points',
          'important_decisions',
          'follow_up_tasks',
        ]) {
          for (final entry in (summary[key] as List?) ?? const []) {
            expect(lines, contains('-> $entry'));
          }
        }
        final items = (summary['action_items'] as List?) ?? const [];
        expect(lines.where((l) => l.contains('(Owner: ')),
            hasLength(items.length));
        expect(text.contains('Summary:'), summary['overall_summary'] != null);
      },
    );

    property<Map<String, dynamic>>(
      'summary JSON round-trips through tryParseMeetingSummary',
      _summary,
      (summary) {
        expect(MeetingFormatter.tryParseMeetingSummary(jsonEncode(summary)),
            summary);
        expect(MeetingFormatter.tryParseMeetingSummary(summary), same(summary));
      },
    );

    property<List<Map<String, dynamic>>>(
      'RAG output has one block per row, split by separators',
      Gens.listOf(
        (r) => <String, dynamic>{
          'entity_type': Gens.nullable(
              Gens.oneOf(['meeting', 'task', 'ticket', 'doc']))(r),
          'title': Gens.nullable(Gens.word())(r),
          'content': Gens.nullable(Gens.oneOf<Object>([
            'plain text',
            '',
            jsonEncode({'overall_summary': 'ok'}),
            {'overall_summary': 'map'},
          ]))(r),
          'similarity': Gens.nullable((r) => r.nextDouble())(r),
        },
        maxLength: 6,
      ),
      (rows) {
        final text = MeetingFormatter.formatRagResults(rows);

        if (rows.isEmpty) {
          expect(text, 'No relevant context found.');
          return;
        }
        expect(RegExp('-{40}').allMatches(text), hasLength(rows.length - 1));
        expect(RegExp(r'\(similarity: ').allMatches(text),
            hasLength(rows.where((r) => r['similarity'] != null).length));
      },
    );
  });

  group('RagResult', () {
    property<RagResult>(
      'toMap then fromMap reproduces the same row',
      (r) => RagResult(
        entityType: Gens.oneOf(RagEntityType.values)(r),
        entityId: Gens.string()(r),
        title: Gens.string()(r),
        content: Gens.nullable(Gens.string())(r),
        similarity: Gens.nullable((r) => r.nextDouble())(r),
        createdAt: Gens.nullable(Gens.dateTime())(r),
        updatedAt: Gens.nullable(Gens.dateTime())(r),
        meetingDate: Gens.nullable(Gens.dateTime())(r),
        dueDate: Gens.nullable(Gens.dateTime())(r),
        priority: Gens.nullable(Gens.word())(r),
        status: Gens.nullable(Gens.word())(r),
        recencyScore: Gens.nullable((r) => r.nextDouble())(r),
        urgencyScore: Gens.nullable((r) => r.nextDouble())(r),
        finalScore: Gens.nullable((r) => r.nextDouble())(r),
      ),
      (result) {
        final map = result.toMap();
        final again = RagResult.fromMap(map);

        expect(again.toMap(), map);
        expect(again.createdAt, result.createdAt);
        expect(again.similarity, result.similarity);
      },
    );

    property<Map<String, dynamic>>(
      'fromMap accepts arbitrary column values without throwing',
      (r) {
        final values = <Object?>[
          null,
          1,
          2.5,
          'text',
          '0.4',
          '2026-01-01',
          true,
          const <int>[],
          DateTime.utc(2026),
        ];
        return {
          for (final key in [
            'entity_type',
            'entity_id',
            'title',
            'content',
            'similarity',
            'created_at',
            'due_date',
            'final_score',
          ])
            key: values[r.nextInt(values.length)],
        };
      },
      (map) {
        final result = RagResult.fromMap(map);

        expect(result.title, isNotEmpty);
        expect(RagEntityType.values, contains(result.entityType));
        if (map['similarity'] is num) {
          expect(result.similarity, (map['similarity'] as num).toDouble());
        }
      },
    );
  });
}
