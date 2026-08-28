import 'package:flutter/foundation.dart';

import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/rag_scoring.dart';

typedef RagRpcCaller = Future<dynamic> Function(
  String functionName, {
  Map<String, dynamic>? params,
});

/// Calls the existing pipeline:
/// `queue_embedding` → `search_rag_by_resp_id` → `rag_search`.
///
/// Does not create embeddings or SQL itself.
class RagRetriever {
  final RagRpcCaller rpc;

  /// Final number of results returned after hybrid ranking.
  final int matchCount;

  /// Minimum cosine similarity before hybrid ranking / return.
  final double similarityThreshold;

  /// Optional larger HNSW candidate pool; null lets SQL choose (~3× matchCount).
  final int? candidateCount;

  const RagRetriever({
    required this.rpc,
    this.matchCount = RagScoring.defaultMatchCount,
    this.similarityThreshold = RagScoring.defaultSimilarityThreshold,
    this.candidateCount,
  });

  Future<RagRetrievalOutcome> retrieve(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const RagRetrievalOutcome.empty();
    }

    try {
      final respIdResponse = await rpc(
        'queue_embedding',
        params: {'query_text': trimmed},
      );

      if (respIdResponse is! int) {
        debugPrint('RAG: unexpected queue_embedding response: $respIdResponse');
        return const RagRetrievalOutcome.error(
          'Could not search workspace context.',
        );
      }

      final safeMatch = RagScoring.boundMatchCount(matchCount);
      final params = <String, dynamic>{
        'resp_id': respIdResponse,
        'match_count': safeMatch,
        'similarity_threshold': similarityThreshold,
      };
      if (candidateCount != null) {
        params['candidate_count'] =
            RagScoring.boundCandidateCount(candidateCount, safeMatch);
      }

      final response = await rpc(
        'search_rag_by_resp_id',
        params: params,
      );

      if (response is! List) {
        return const RagRetrievalOutcome.empty();
      }

      final results = <RagResult>[];
      for (final row in response) {
        if (row is Map) {
          results.add(RagResult.fromMap(Map<String, dynamic>.from(row)));
        }
      }

      final filtered = RagRetrievalOutcome.success(results)
          .filteredBySimilarity(threshold: similarityThreshold);

      if (!filtered.hasResults) {
        return const RagRetrievalOutcome.empty();
      }

      return filtered;
    } catch (e, st) {
      debugPrint('RAG retrieval failed: $e\n$st');
      return const RagRetrievalOutcome.error(
        'Could not search workspace context.',
      );
    }
  }
}
