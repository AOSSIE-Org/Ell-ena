import 'package:ell_ena/models/chat_message.dart';
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/chat_controller.dart';
import 'package:ell_ena/services/rag_retriever.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatController', () {
    test('stores success retrieval and targeted AI context', () async {
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(
            RagRetriever(
              rpc: (functionName, {params}) async {
                if (functionName == 'queue_embedding') return 7;
                return [
                  {
                    'entity_type': 'ticket',
                    'entity_id': 'tick-auth',
                    'title': 'OAuth redirect broken',
                    'content': 'Users bounce after Google consent.',
                    'similarity': 0.88,
                  },
                ];
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      final outcome = await notifier.retrieveForQuery('authentication issue');
      final state = container.read(chatControllerProvider);

      expect(outcome.status, RagRetrievalStatus.success);
      expect(state.retrievalStatus, RagRetrievalStatus.success);
      expect(state.retrievalResults, hasLength(1));
      expect(state.aiContext, contains('OAuth redirect broken'));
      expect(state.aiContext, isNot(contains('Order office snacks')));
      expect(state.retrievalError, isNull);
    });

    test('stores empty retrieval without injecting workspace context',
        () async {
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(
            RagRetriever(
              rpc: (functionName, {params}) async {
                if (functionName == 'queue_embedding') return 1;
                return <dynamic>[];
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatControllerProvider.notifier)
          .retrieveForQuery('nothing matches');
      final state = container.read(chatControllerProvider);

      expect(state.retrievalStatus, RagRetrievalStatus.empty);
      expect(state.retrievalResults, isEmpty);
      expect(state.aiContext, isEmpty);
    });

    test('stores a user-safe retrieval error and empty context', () async {
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(
            RagRetriever(
              rpc: (functionName, {params}) async {
                throw Exception('service_role=super-secret');
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(chatControllerProvider.notifier)
          .retrieveForQuery('auth');
      final state = container.read(chatControllerProvider);

      expect(outcome.status, RagRetrievalStatus.error);
      expect(state.retrievalStatus, RagRetrievalStatus.error);
      expect(state.aiContext, isEmpty);
      expect(state.retrievalError, 'Could not search workspace context.');
      expect(state.retrievalError, isNot(contains('secret')));
    });

    test('historyForAi excludes the latest user turn', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(chatControllerProvider.notifier);

      notifier.addWelcomeIfEmpty();
      notifier.addMessage(
        ChatMessage(
          text: 'What about auth?',
          isUser: true,
          timestamp: DateTime(2026, 8, 11),
        ),
      );

      final history = notifier.historyForAi();
      expect(history, hasLength(1));
      expect(history.single['content'], contains('Ell-ena'));
      expect(
        history.any((message) => message['content'] == 'What about auth?'),
        isFalse,
      );
    });
  });
}
