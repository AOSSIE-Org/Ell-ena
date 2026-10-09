import 'package:ell_ena/models/chat_message.dart';
import 'package:ell_ena/models/rag_result.dart';

/// Conversation, retrieval, and AI-context state for the assistant.
class ChatState {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final List<Map<String, dynamic>> teamMembers;
  final RagRetrievalStatus retrievalStatus;
  final List<RagResult> retrievalResults;
  final String aiContext;
  final String? retrievalError;

  const ChatState({
    this.messages = const [],
    this.isProcessing = false,
    this.teamMembers = const [],
    this.retrievalStatus = RagRetrievalStatus.idle,
    this.retrievalResults = const [],
    this.aiContext = '',
    this.retrievalError,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isProcessing,
    List<Map<String, dynamic>>? teamMembers,
    RagRetrievalStatus? retrievalStatus,
    List<RagResult>? retrievalResults,
    String? aiContext,
    String? retrievalError,
    bool clearRetrievalError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      teamMembers: teamMembers ?? this.teamMembers,
      retrievalStatus: retrievalStatus ?? this.retrievalStatus,
      retrievalResults: retrievalResults ?? this.retrievalResults,
      aiContext: aiContext ?? this.aiContext,
      retrievalError:
          clearRetrievalError ? null : (retrievalError ?? this.retrievalError),
    );
  }
}
