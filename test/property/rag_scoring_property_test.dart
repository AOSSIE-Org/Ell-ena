import 'dart:math';

import 'package:ell_ena/services/rag_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/property.dart';

double unit(Random r) => r.nextDouble();

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);
  final statuses = Gens.oneOf<String?>(
      [null, 'todo', 'in_progress', 'completed', 'blocked', '']);
  final priorities = Gens.oneOf<String?>(
      [null, 'high', 'HIGH', 'medium', 'Medium', 'low', 'critical', '']);
  final ticketStatuses =
      Gens.oneOf<String?>([null, 'open', 'in_progress', 'resolved', 'closed']);

  /// Offsets in minutes from [now], up to two years either way.
  final offsets = Gens.intIn(-60 * 24 * 730, 60 * 24 * 730);

  test('defaults to the current time and gives meetings no urgency', () {
    expect(RagScoring.recencyScore(null), 1.0);
    expect(
      RagScoring.recencyScore(DateTime.now().add(const Duration(days: 1))),
      1.0,
    );
    expect(
      RagScoring.taskUrgency(
          status: 'todo',
          dueDate: DateTime.now().subtract(const Duration(days: 1))),
      1.0,
    );
    expect(RagScoring.meetingUrgency(), 0.0);
  });

  group('recencyScore', () {
    property<List<int>>(
      'is in (0, 1] and never grows as items get older',
      (r) => [offsets(r), offsets(r)],
      (pair) {
        final a = now.add(Duration(minutes: pair[0]));
        final b = now.add(Duration(minutes: pair[1]));
        final scoreA = RagScoring.recencyScore(a, now: now);
        final scoreB = RagScoring.recencyScore(b, now: now);

        expect(scoreA, inInclusiveRange(0, 1));
        expect(scoreA, greaterThan(0));
        if (a.isBefore(b)) expect(scoreA, lessThanOrEqualTo(scoreB));
      },
    );

    property<int>(
      'is exactly 1 for now and any future date',
      Gens.intIn(0, 60 * 24 * 365),
      (minutes) {
        expect(
          RagScoring.recencyScore(now.add(Duration(minutes: minutes)),
              now: now),
          1.0,
        );
      },
    );

    property<int>(
      'halves roughly every half-life',
      Gens.intIn(1, 10),
      (halfLives) {
        final age =
            Duration(hours: (RagScoring.halfLifeDays * 24 * halfLives).round());
        final score = RagScoring.recencyScore(now.subtract(age), now: now);
        final next = RagScoring.recencyScore(now.subtract(age * 2), now: now);

        // exp(-2x) == exp(-x)^2
        expect(next, closeTo(score * score, 1e-9));
      },
    );
  });

  group('taskUrgency', () {
    property<List<Object?>>(
      'is in [0, 1], zero when completed, one when overdue',
      (r) => [statuses(r), Gens.nullable(offsets)(r)],
      (input) {
        final status = input[0] as String?;
        final offset = input[1] as int?;
        final due = offset == null ? null : now.add(Duration(minutes: offset));
        final urgency =
            RagScoring.taskUrgency(status: status, dueDate: due, now: now);

        expect(urgency, inInclusiveRange(0, 1));
        if (status == 'completed') expect(urgency, 0);
        if (status != 'completed' && due != null && due.isBefore(now)) {
          expect(urgency, 1);
        }
      },
    );

    property<List<Object?>>(
      'never rises as the due date moves later',
      (r) => [statuses(r), offsets(r), Gens.intIn(0, 60 * 24 * 30)(r)],
      (input) {
        final status = input[0] as String?;
        final early = now.add(Duration(minutes: input[1] as int));
        final late = early.add(Duration(minutes: input[2] as int));

        expect(
          RagScoring.taskUrgency(status: status, dueDate: late, now: now),
          lessThanOrEqualTo(
              RagScoring.taskUrgency(status: status, dueDate: early, now: now)),
        );
      },
    );
  });

  group('ticketUrgency', () {
    property<List<String?>>(
      'is in [0, 1] and zero once resolved',
      (r) => [priorities(r), ticketStatuses(r)],
      (input) {
        final urgency =
            RagScoring.ticketUrgency(priority: input[0], status: input[1]);

        expect(urgency, inInclusiveRange(0, 1));
        if (input[1] == 'resolved') expect(urgency, 0);
      },
    );

    property<String?>(
      'ranks high ≥ medium ≥ low for the same status',
      ticketStatuses,
      (status) {
        double score(String p) =>
            RagScoring.ticketUrgency(priority: p, status: status);

        expect(score('high'), greaterThanOrEqualTo(score('medium')));
        expect(score('medium'), greaterThanOrEqualTo(score('low')));
        expect(score('HIGH'), score('high'));
      },
    );

    property<String?>(
      'active tickets are at least as urgent as closed ones',
      priorities,
      (priority) {
        final active =
            RagScoring.ticketUrgency(priority: priority, status: 'open');
        final closed =
            RagScoring.ticketUrgency(priority: priority, status: 'closed');

        expect(active, greaterThanOrEqualTo(closed));
        expect(
            RagScoring.ticketUrgency(priority: priority, status: 'in_progress'),
            active);
      },
    );
  });

  group('finalScore', () {
    property<List<double>>(
      'stays in [0, 1] and is led by similarity',
      (r) => [unit(r), unit(r), unit(r), unit(r)],
      (v) {
        final score = RagScoring.finalScore(
            similarity: v[0], recency: v[1], urgency: v[2]);
        final higher = RagScoring.finalScore(
            similarity: v[0] + (1 - v[0]) * v[3], recency: v[1], urgency: v[2]);

        expect(score, inInclusiveRange(0, 1));
        expect(higher, greaterThanOrEqualTo(score));
        // Full recency and urgency add 0.10; a 0.12 similarity lead adds 0.108.
        expect(
          RagScoring.finalScore(similarity: v[0], recency: 1, urgency: 1),
          lessThan(RagScoring.finalScore(
                  similarity: v[0] + 0.12, recency: 0, urgency: 0) +
              1e-9),
        );
      },
    );
  });

  group('similarity floor', () {
    property<List<double>>(
      'anything above a passing score also passes',
      (r) => [unit(r), unit(r), unit(r)],
      (v) {
        final low = v[0] < v[1] ? v[0] : v[1];
        final high = v[0] < v[1] ? v[1] : v[0];
        if (RagScoring.passesSimilarityFloor(low, threshold: v[2])) {
          expect(
              RagScoring.passesSimilarityFloor(high, threshold: v[2]), isTrue);
        }
        expect(RagScoring.passesSimilarityFloor(v[2], threshold: v[2]), isTrue);
      },
    );
  });

  group('result counts', () {
    property<int>(
      'boundMatchCount clamps to [1, 25] and is idempotent',
      Gens.intIn(-1000, 1000),
      (n) {
        final bounded = RagScoring.boundMatchCount(n);

        expect(bounded, inInclusiveRange(1, RagScoring.maxMatchCount));
        expect(RagScoring.boundMatchCount(bounded), bounded);
        if (n >= 1 && n <= RagScoring.maxMatchCount) expect(bounded, n);
      },
    );

    property<List<int?>>(
      'the candidate pool covers the match count and stays under 50',
      (r) => [Gens.nullable(Gens.intIn(-100, 200))(r), Gens.intIn(-50, 100)(r)],
      (input) {
        final pool = RagScoring.boundCandidateCount(input[0], input[1]!);
        final match = RagScoring.boundMatchCount(input[1]!);

        expect(pool, greaterThanOrEqualTo(match));
        expect(pool, lessThanOrEqualTo(RagScoring.maxCandidateCount));
        expect(RagScoring.boundCandidateCount(pool, input[1]!), pool);
        if (input[0] == null) expect(pool, greaterThanOrEqualTo(9));
      },
    );
  });
}
