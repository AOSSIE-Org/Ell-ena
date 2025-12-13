import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vector_database_interface.dart';

/// PostgreSQL with pgvector extension implementation
/// 
/// This is the current implementation used by Ell-ena.
/// Uses Supabase client to interact with PostgreSQL vector functions.
class PgVectorDatabase implements VectorDatabase {
  final SupabaseClient _supabaseClient;
  bool _isInitialized = false;

  PgVectorDatabase(this._supabaseClient);

  @override
  String get providerName => 'PostgreSQL (pgvector)';

  @override
  Future<void> initialize() async {
    try {
      // Test connection by checking if vector extension is available
      final response = await _supabaseClient.rpc('get_similar_meetings', params: {
        'query_embedding': List.filled(768, 0.0),
        'match_count': 1,
      });
      
      _isInitialized = true;
      debugPrint('✅ PgVector initialized successfully');
    } catch (e) {
      debugPrint('❌ PgVector initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<bool> storeEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      // Update the meetings table with the embedding
      final response = await _supabaseClient
          .from('meetings')
          .update({
            'summary_embedding': embedding,
            'meeting_summary_json': metadata,
          })
          .eq('id', id);

      debugPrint('✅ Embedding stored for meeting: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Error storing embedding: $e');
      return false;
    }
  }

  @override
  Future<List<VectorSearchResult>> searchSimilar({
    required List<double> queryEmbedding,
    int limit = 5,
    double similarityThreshold = 0.0,
  }) async {
    try {
      // Queue the embedding request and get the response ID
      final respIdResponse = await _supabaseClient.rpc(
        'queue_embedding',
        params: {
          'query_text': '', // Will be provided externally
        },
      );

      final respId = respIdResponse as int;

      // Fetch meetings using the resp_id
      final response = await _supabaseClient.rpc(
        'search_meeting_summaries_by_resp_id',
        params: {
          'resp_id': respId,
          'match_count': limit,
          'similarity_threshold': similarityThreshold,
        },
      );

      final List<dynamic> results = response as List<dynamic>;

      return results.map((result) {
        return VectorSearchResult(
          id: result['meeting_id'].toString(),
          similarity: (result['similarity'] as num).toDouble(),
          metadata: {
            'title': result['title'],
            'meeting_date': result['meeting_date'],
            'summary': result['summary'],
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching similar vectors: $e');
      return [];
    }
  }

  /// Alternative search method that uses direct embedding
  Future<List<VectorSearchResult>> searchSimilarDirect({
    required List<double> queryEmbedding,
    int limit = 5,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_similar_meetings',
        params: {
          'query_embedding': queryEmbedding,
          'match_count': limit,
        },
      );

      final List<dynamic> results = response as List<dynamic>;

      return results.map((result) {
        return VectorSearchResult(
          id: result['meeting_id'].toString(),
          similarity: (result['similarity'] as num).toDouble(),
          metadata: {
            'title': result['title'],
            'meeting_date': result['meeting_date'],
            'summary': result['summary'],
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error in direct search: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteEmbedding(String id) async {
    try {
      // Set the embedding to null
      await _supabaseClient
          .from('meetings')
          .update({'summary_embedding': null})
          .eq('id', id);

      debugPrint('✅ Embedding deleted for meeting: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting embedding: $e');
      return false;
    }
  }

  @override
  Future<bool> updateEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  }) async {
    // Same as store for pgvector
    return storeEmbedding(
      id: id,
      embedding: embedding,
      metadata: metadata,
    );
  }

  @override
  Future<bool> isHealthy() async {
    if (!_isInitialized) return false;

    try {
      // Simple health check - try to query
      await _supabaseClient
          .from('meetings')
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    // Supabase client is managed externally
    _isInitialized = false;
    debugPrint('✅ PgVector connection closed');
  }
}
