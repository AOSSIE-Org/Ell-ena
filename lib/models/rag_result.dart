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

  const RagResult({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.content,
    this.similarity,
  });

  factory RagResult.fromMap(Map<String, dynamic> map) {
    final similarityValue = map['similarity'];
    return RagResult(
      entityType: RagEntityType.fromString(map['entity_type']?.toString()),
      entityId: map['entity_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      content: map['content']?.toString(),
      similarity: similarityValue is num ? similarityValue.toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType.label,
      'entity_id': entityId,
      'title': title,
      'content': content,
      'similarity': similarity,
    };
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
}
