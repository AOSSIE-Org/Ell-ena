import 'dart:core';
import 'package:flutter/foundation.dart';

class ContextPruningService {
  /// Estimates the number of tokens based on a character heuristic (approx. 4 chars per token).
  int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }

  /// Calculates a lightweight keyword overlap score as a fallback
  /// if the vector search similarity score is unavailable.
  double _calculateKeywordOverlap(String query, String text) {
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).toSet();
    final textWords = text.toLowerCase().split(RegExp(r'\s+')).toSet();
    
    if (queryWords.isEmpty || textWords.isEmpty) return 0.0;
    
    final intersection = queryWords.intersection(textWords);
    return intersection.length / queryWords.length;
  }

  /// Prunes the list of meeting contexts based on relevance and a token budget.
  List<Map<String, dynamic>> prune({
    required String query,
    required List<Map<String, dynamic>> meetings,
    required int maxTokens,
  }) {
    final stopwatch = Stopwatch()..start();
    
    // Create deep copies to avoid modifying cached references
    List<Map<String, dynamic>> chunks = meetings.map((m) => Map<String, dynamic>.from(m)).toList();
    
    int originalTokens = 0;
    int chunksRemoved = 0;

    // 1. Scoring & Initial Token Counting
    for (var chunk in chunks) {
      final summaryStr = chunk['summary']?.toString() ?? '';
      final tokenCount = _estimateTokens(summaryStr);
      originalTokens += tokenCount;
      chunk['_token_count'] = tokenCount;

      // Use existing similarity if provided by vector search, else fallback to keyword overlap
      if (chunk.containsKey('similarity') && chunk['similarity'] != null) {
        chunk['_relevance_score'] = (chunk['similarity'] as num).toDouble();
      } else {
        chunk['_relevance_score'] = _calculateKeywordOverlap(query, summaryStr);
      }
    }

    // 2. Rank contexts from highest relevance to lowest
    chunks.sort((a, b) {
      final scoreA = a['_relevance_score'] as double;
      final scoreB = b['_relevance_score'] as double;
      return scoreB.compareTo(scoreA); // Descending order
    });

    // 3. Sliding-Window Pruning (Remove lowest-ranked chunks until under budget)
    List<Map<String, dynamic>> optimizedChunks = [];
    int currentTokens = 0;

    for (var chunk in chunks) {
      final tokenCount = chunk['_token_count'] as int;
      
      if (currentTokens + tokenCount <= maxTokens) {
        optimizedChunks.add(chunk);
        currentTokens += tokenCount;
      } else {
        // Enforce strict truncation for the last partially fitting chunk
        int remainingTokens = maxTokens - currentTokens;
        
        if (remainingTokens > 100 && chunk['summary'] != null) {
          var partialSummary = Map<String, dynamic>.from(chunk['summary']);
          
          if (partialSummary['overall_summary'] != null) {
             String overall = partialSummary['overall_summary'].toString();
             int allowedChars = remainingTokens * 4;
             
             if (overall.length > allowedChars) {
               partialSummary['overall_summary'] = 
                   overall.substring(0, allowedChars) + '\n... [TRUNCATED DUE TO TOKEN BUDGET]';
             }
          }
          chunk['summary'] = partialSummary;
          optimizedChunks.add(chunk);
          currentTokens += remainingTokens;
        } else {
          chunksRemoved++;
        }
      }
    }

    // Accumulate skipped chunks in the count
    chunksRemoved += (chunks.length - optimizedChunks.length - (chunksRemoved > 0 ? 0 : 0));

    stopwatch.stop();

    // 4. Debug Logging & Reduction Metrics
    final double reductionPct = originalTokens > 0 
        ? ((originalTokens - currentTokens) / originalTokens) * 100 
        : 0.0;

    debugPrint('--- Context-Window Pruning Metrics ---');
    debugPrint('Original Tokens: $originalTokens');
    debugPrint('Final Tokens: $currentTokens');
    debugPrint('Reduction: ${reductionPct.toStringAsFixed(2)}%');
    debugPrint('Chunks Removed: $chunksRemoved');
    debugPrint('Latency: ${stopwatch.elapsedMilliseconds} ms');
    debugPrint('--------------------------------------');

    // Clean up internal metric keys before returning
    for (var chunk in optimizedChunks) {
      chunk.remove('_token_count');
      chunk.remove('_relevance_score');
    }

    return optimizedChunks;
  }
}
