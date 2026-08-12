import 'package:flutter/foundation.dart';

import 'package:ell_ena/models/rag_result.dart';

typedef RagRpcCaller = Future<dynamic> Function(
  String functionName, {
  Map<String, dynamic>? params,
});

/// Calls the existing Week 13 pipeline:
/// `queue_embedding` → `search_rag_by_resp_id` → `rag_search`.
///
/// Does not create embeddings or SQL itself.
class RagRetriever {
  final RagRpcCaller rpc;
  final int matchCount;

  const RagRetriever({
    required this.rpc,
    this.matchCount = 5,
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

      final response = await rpc(
        'search_rag_by_resp_id',
        params: {
          'resp_id': respIdResponse,
          'match_count': matchCount,
        },
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

      if (results.isEmpty) {
        return const RagRetrievalOutcome.empty();
      }

      return RagRetrievalOutcome.success(results);
    } catch (e, st) {
      debugPrint('RAG retrieval failed: $e\n$st');
      return const RagRetrievalOutcome.error(
        'Could not search workspace context.',
      );
    }
  }
}
