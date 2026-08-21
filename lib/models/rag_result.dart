import 'package:ell_ena/services/rag_scoring.dart';

/// Entity kinds returned by `rag_search` / `search_rag_by_resp_id`.
enum RagEntityType {
  meeting,
  task,
  ticket,
  unknown;

  static RagEntityType fromString(String? value) {
    switch (value) {
      case 'meeting':
        return RagEntityType.meeting;
      case 'task':
        return RagEntityType.task;
      case 'ticket':
        return RagEntityType.ticket;
      default:
        return RagEntityType.unknown;
    }
  }

  String get label {
    switch (this) {
      case RagEntityType.meeting:
        return 'meeting';
      case RagEntityType.task:
        return 'task';
      case RagEntityType.ticket:
        return 'ticket';
      case RagEntityType.unknown:
        return 'unknown';
    }
  }
}

enum RagRetrievalStatus {
  idle,
  loading,
  success,
  empty,
  error,
}

/// One ranked row from unified semantic retrieval.
class RagResult {
  final RagEntityType entityType;
  final String entityId;
  final String title;
  final String? content;
  final double? similarity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? meetingDate;
  final DateTime? dueDate;
  final String? priority;
  final String? status;
  final double? recencyScore;
  final double? urgencyScore;
  final double? finalScore;

  const RagResult({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.content,
    this.similarity,
    this.createdAt,
    this.updatedAt,
    this.meetingDate,
    this.dueDate,
    this.priority,
    this.status,
    this.recencyScore,
    this.urgencyScore,
    this.finalScore,
  });

  factory RagResult.fromMap(Map<String, dynamic> map) {
    return RagResult(
      entityType: RagEntityType.fromString(map['entity_type']?.toString()),
      entityId: map['entity_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      content: map['content']?.toString(),
      similarity: _asDouble(map['similarity']),
      createdAt: _asDateTime(map['created_at']),
      updatedAt: _asDateTime(map['updated_at']),
      meetingDate: _asDateTime(map['meeting_date']),
      dueDate: _asDateTime(map['due_date']),
      priority: map['priority']?.toString(),
      status: map['status']?.toString(),
      recencyScore: _asDouble(map['recency_score']),
      urgencyScore: _asDouble(map['urgency_score']),
      finalScore: _asDouble(map['final_score']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType.label,
      'entity_id': entityId,
      'title': title,
      'content': content,
      'similarity': similarity,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'meeting_date': meetingDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'priority': priority,
      'status': status,
      'recency_score': recencyScore,
      'urgency_score': urgencyScore,
      'final_score': finalScore,
    };
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// Outcome of a single semantic retrieval attempt.
class RagRetrievalOutcome {
  final RagRetrievalStatus status;
  final List<RagResult> results;
  final String? errorMessage;

  const RagRetrievalOutcome._({
    required this.status,
    this.results = const [],
    this.errorMessage,
  });

  const RagRetrievalOutcome.idle() : this._(status: RagRetrievalStatus.idle);

  const RagRetrievalOutcome.loading()
      : this._(status: RagRetrievalStatus.loading);

  const RagRetrievalOutcome.success(List<RagResult> results)
      : this._(status: RagRetrievalStatus.success, results: results);

  const RagRetrievalOutcome.empty() : this._(status: RagRetrievalStatus.empty);

  const RagRetrievalOutcome.error(String message)
      : this._(status: RagRetrievalStatus.error, errorMessage: message);

  bool get hasResults => results.isNotEmpty;

  /// Drops rows below the similarity floor (defense if RPC omits the filter).
  RagRetrievalOutcome filteredBySimilarity({
    double threshold = RagScoring.defaultSimilarityThreshold,
  }) {
    if (!hasResults) return this;
    final kept = results
        .where(
          (r) =>
              r.similarity == null ||
              RagScoring.passesSimilarityFloor(
                r.similarity!,
                threshold: threshold,
              ),
        )
        .toList();
    if (kept.isEmpty) {
      return const RagRetrievalOutcome.empty();
    }
    return RagRetrievalOutcome.success(kept);
  }
}
