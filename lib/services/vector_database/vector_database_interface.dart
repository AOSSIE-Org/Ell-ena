/// Abstract interface for vector database operations
/// Supports multiple vector database providers (pgvector, Couchbase, Pinecone, etc.)
abstract class VectorDatabase {
  /// Initialize the vector database connection
  Future<void> initialize();

  /// Store an embedding vector with associated metadata
  /// 
  /// Parameters:
  /// - [id]: Unique identifier for the document
  /// - [embedding]: Vector embedding (typically 768 dimensions for Gemini)
  /// - [metadata]: Associated metadata (title, date, content, etc.)
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> storeEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  });

  /// Search for similar vectors using cosine similarity
  /// 
  /// Parameters:
  /// - [queryEmbedding]: The query vector to search for
  /// - [limit]: Maximum number of results to return
  /// - [similarityThreshold]: Minimum similarity score (0.0 to 1.0)
  /// 
  /// Returns: List of similar documents with similarity scores
  Future<List<VectorSearchResult>> searchSimilar({
    required List<double> queryEmbedding,
    int limit = 5,
    double similarityThreshold = 0.0,
  });

  /// Delete an embedding by ID
  /// 
  /// Parameters:
  /// - [id]: Unique identifier of the document to delete
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> deleteEmbedding(String id);

  /// Update an existing embedding
  /// 
  /// Parameters:
  /// - [id]: Unique identifier for the document
  /// - [embedding]: New vector embedding
  /// - [metadata]: Updated metadata
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> updateEmbedding({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  });

  /// Check if the database is properly initialized and connected
  Future<bool> isHealthy();

  /// Close the database connection
  Future<void> close();

  /// Get the name/type of the vector database provider
  String get providerName;
}

/// Result from a vector similarity search
class VectorSearchResult {
  /// Unique identifier of the document
  final String id;

  /// Similarity score (0.0 to 1.0, where 1.0 is identical)
  final double similarity;

  /// Associated metadata
  final Map<String, dynamic> metadata;

  VectorSearchResult({
    required this.id,
    required this.similarity,
    required this.metadata,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'similarity': similarity,
    'metadata': metadata,
  };

  /// Create from JSON
  factory VectorSearchResult.fromJson(Map<String, dynamic> json) {
    return VectorSearchResult(
      id: json['id'] as String,
      similarity: (json['similarity'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }

  @override
  String toString() => 'VectorSearchResult(id: $id, similarity: $similarity)';
}
