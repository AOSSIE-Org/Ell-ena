import 'dart:math' as math;

/// Scoring helpers mirroring hybrid `rag_search` weights.
///
/// Authoritative ranking runs in Postgres; this class supports unit tests and
/// client-side similarity-floor checks.
class RagScoring {
  static const double semanticWeight = 0.70;
  static const double recencyWeight = 0.20;
  static const double urgencyWeight = 0.10;
  static const double halfLifeDays = 21.0;
  static const double defaultSimilarityThreshold = 0.30;

  static const int defaultMatchCount = 5;
  static const int maxMatchCount = 25;
  static const int maxCandidateCount = 50;

  /// Exponential decay: newer → closer to 1.0. Future dates clamp to 1.0.
  static double recencyScore(DateTime? reference, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final anchor = reference ?? clock;
    final ageDays = clock.difference(anchor).inSeconds / 86400.0;
    final clamped = ageDays < 0 ? 0.0 : ageDays;
    return math.exp(-clamped / halfLifeDays);
  }

  /// Meetings use similarity + recency only.
  static double meetingUrgency() => 0.0;

  /// Tasks have no priority column; use due_date + status.
  static double taskUrgency({
    required String? status,
    DateTime? dueDate,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (status == 'completed') return 0.0;
    if (dueDate != null && dueDate.isBefore(clock)) return 1.0;
    if (dueDate != null &&
        !dueDate.isAfter(clock.add(const Duration(days: 3)))) {
      return 0.85;
    }
    if (dueDate != null &&
        !dueDate.isAfter(clock.add(const Duration(days: 7)))) {
      return 0.55;
    }
    if (status == 'in_progress') return 0.45;
    if (status == 'todo') return 0.30;
    return 0.10;
  }

  /// Tickets use priority (low/medium/high) and status.
  static double ticketUrgency({
    required String? priority,
    required String? status,
  }) {
    if (status == 'resolved') return 0.0;
    final p = (priority ?? 'medium').toLowerCase();
    double priorityScore;
    if (p == 'high') {
      priorityScore = 1.0;
    } else if (p == 'medium') {
      priorityScore = 0.50;
    } else if (p == 'low') {
      priorityScore = 0.20;
    } else {
      priorityScore = 0.35;
    }
    final statusFactor =
        (status == 'open' || status == 'in_progress') ? 1.0 : 0.40;
    return priorityScore * statusFactor;
  }

  static double finalScore({
    required double similarity,
    required double recency,
    required double urgency,
  }) {
    return semanticWeight * similarity +
        recencyWeight * recency +
        urgencyWeight * urgency;
  }

  static bool passesSimilarityFloor(
    double similarity, {
    double threshold = defaultSimilarityThreshold,
  }) {
    return similarity >= threshold;
  }

  /// Mirrors SQL bounds: pool in [matchCount, 50], matchCount in [1, 25].
  static int boundMatchCount(int matchCount) {
    if (matchCount < 1) return 1;
    if (matchCount > maxMatchCount) return maxMatchCount;
    return matchCount;
  }

  static int boundCandidateCount(int? candidateCount, int matchCount) {
    final safeMatch = boundMatchCount(matchCount);
    final raw = candidateCount ?? math.max(safeMatch * 3, 9);
    final atLeastMatch = raw < safeMatch ? safeMatch : raw;
    if (atLeastMatch > maxCandidateCount) return maxCandidateCount;
    return atLeastMatch;
  }
}
