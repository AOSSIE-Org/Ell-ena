import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ell_ena/models/chat_message.dart';
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/models/chat_state.dart';
import 'package:ell_ena/services/ai_context_builder.dart';
import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/services/rag_retriever.dart';

final aiServiceProvider = Provider<AIService>((ref) => AIService());

final ragRetrieverProvider = Provider<RagRetriever>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return RagRetriever(rpc: aiService.invokeRpc);
});

/// Owns conversation transcript plus retrieval/AI-context state.
///
/// Gemini responses are produced by [AIService]; this notifier stores the
/// resulting messages and the targeted context used for the last turn.
class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  void addWelcomeIfEmpty() {
    if (state.messages.isNotEmpty) return;
    state = state.copyWith(
      messages: [
        ChatMessage(
          text:
              "Hello! I'm Ell-ena, your AI assistant. How can I help you today?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void setTeamMembers(List<Map<String, dynamic>> members) {
    state =
        state.copyWith(teamMembers: List<Map<String, dynamic>>.from(members));
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Runs existing `rag_search` via [RagRetriever] and stores targeted context.
  Future<RagRetrievalOutcome> retrieveForQuery(String query) async {
    state = state.copyWith(
      retrievalStatus: RagRetrievalStatus.loading,
      clearRetrievalError: true,
    );

    final outcome = await ref.read(ragRetrieverProvider).retrieve(query);
    final context = AiContextBuilder.buildWorkspaceContext(outcome);

    state = state.copyWith(
      retrievalStatus: outcome.status,
      retrievalResults: outcome.results,
      aiContext: context,
      retrievalError: outcome.errorMessage,
      clearRetrievalError: outcome.errorMessage == null,
    );

    return outcome;
  }

  /// Recent turns for Gemini, excluding the latest user message (added
  /// separately as the current turn).
  List<Map<String, String>> historyForAi({int limit = 10}) {
    var source = state.messages;
    if (source.isNotEmpty && source.last.isUser) {
      source = source.sublist(0, source.length - 1);
    }
    final recent =
        source.length > limit ? source.sublist(source.length - limit) : source;
    return recent
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'model',
            'content': message.text,
          },
        )
        .toList();
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
