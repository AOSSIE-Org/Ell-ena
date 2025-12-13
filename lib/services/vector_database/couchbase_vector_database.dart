import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'vector_database_interface.dart';

/// Couchbase vector database implementation
/// 
/// Uses Couchbase Server's Full-Text Search (FTS) with vector capabilities
/// for high-performance vector similarity search.
/// 
/// Features:
/// - Fast vector search using Couchbase FTS
/// - Horizontal scalability
/// - Built-in caching
/// - Multi-model database (documents + vectors)
class CouchbaseVectorDatabase implements VectorDatabase {
  final String clusterUrl;
  final String username;
  final String password;
  final String bucketName;
  final String scopeName;
  final String collectionName;
  final String searchIndexName;

  late http.Client _httpClient;
  bool _isInitialized = false;
  late String _authHeader;

  CouchbaseVectorDatabase({
    required this.clusterUrl,
    required this.username,
    required this.password,
    required this.bucketName,
    this.scopeName = '_default',
    this.collectionName = '_default',
    this.searchIndexName = 'vector_index',
  }) {
    _httpClient = http.Client();
    _authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  @override
  String get providerName => 'Couchbase Server';

  @override
  Future<void> initialize() async {
    try {
      // Test connection by checking cluster health
      final response = await _httpClient.get(
        Uri.parse('$clusterUrl/pools/default'),
        headers: {'Authorization': _authHeader},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection to Couchbase cluster timed out');
        },
      );

      if (response.statusCode == 200) {
        _isInitialized = true;
        debugPrint('✅ Couchbase initialized successfully');
        
        // Verify search index exists
        await _verifySearchIndex();
      } else {
        throw Exception('Failed to connect: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Couchbase initialization timeout: $e');
      _isInitialized = false;
      rethrow;
    } catch (e) {
      debugPrint('❌ Couchbase initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Verify that the vector search index exists
  Future<void> _verifySearchIndex() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$clusterUrl/api/index/$searchIndexName'),
        headers: {'Authorization': _authHeader},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Search index verification timed out');
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Search index "$searchIndexName" verified');
      } else {
        debugPrint('⚠️  Search index "$searchIndexName" not found');
        debugPrint('   Please create the index using Couchbase Web UI');
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️  Search index verification timeout: $e');
    } catch (e) {
      debugPrint('⚠️  Could not verify search index: $e');
    }
  }

  @override
  Future<bool> storeEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final document = {
        'type': 'meeting_embedding',
        'id': id,
        'embedding': embedding,
        'dimensions': embedding.length,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      };

      final keyPath = '$bucketName/$scopeName/$collectionName/$id';
      final response = await _httpClient.put(
        Uri.parse('$clusterUrl/pools/default/buckets/$keyPath'),
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(document),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Store embedding request timed out');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Embedding stored in Couchbase: $id');
        return true;
      } else {
        debugPrint('❌ Failed to store: ${response.statusCode} - ${response.body}');
        return false;
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Store embedding timeout: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Error storing embedding in Couchbase: $e');
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
      // Couchbase FTS vector search query
      final searchQuery = {
        'query': {
          'field': 'embedding',
          'vector': queryEmbedding,
          'k': limit,
        },
        'size': limit,
        'from': 0,
      };

      final response = await _httpClient.post(
        Uri.parse('$clusterUrl/api/index/$searchIndexName/query'),
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(searchQuery),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Vector search request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data['hits'] as List<dynamic>;

        final results = hits
            .map((hit) {
              final doc = hit['fields'] as Map<String, dynamic>;
              final score = (hit['score'] as num).toDouble();

              // Convert score to similarity (0-1 range)
              // Couchbase returns distance scores, we normalize them
              final similarity = 1.0 / (1.0 + score);

              if (similarity < similarityThreshold) return null;

              return VectorSearchResult(
                id: doc['id']?.toString() ?? '',
                similarity: similarity,
                metadata: doc['metadata'] as Map<String, dynamic>? ?? {},
              );
            })
            .whereType<VectorSearchResult>()
            .toList();

        debugPrint('✅ Found ${results.length} similar vectors in Couchbase');
        return results;
      } else {
        debugPrint('❌ Search failed: ${response.statusCode} - ${response.body}');
        return [];
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Vector search timeout: $e');
      return [];
    } catch (e) {
      debugPrint('❌ Error searching in Couchbase: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteEmbedding(String id) async {
    try {
      final keyPath = '$bucketName/$scopeName/$collectionName/$id';
      final response = await _httpClient.delete(
        Uri.parse('$clusterUrl/pools/default/buckets/$keyPath'),
        headers: {'Authorization': _authHeader},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Delete embedding request timed out');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Embedding deleted from Couchbase: $id');
        return true;
      } else {
        debugPrint('❌ Failed to delete: ${response.statusCode}');
        return false;
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Delete embedding timeout: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting from Couchbase: $e');
      return false;
    }
  }

  @override
  Future<bool> updateEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  }) async {
    // Couchbase uses upsert, so update is same as store
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
      final response = await _httpClient.get(
        Uri.parse('$clusterUrl/pools/default'),
        headers: {'Authorization': _authHeader},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Health check request timed out');
        },
      );

      return response.statusCode == 200;
    } on TimeoutException catch (e) {
      debugPrint('❌ Health check timeout: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    _httpClient.close();
    _isInitialized = false;
    debugPrint('✅ Couchbase connection closed');
  }
}
