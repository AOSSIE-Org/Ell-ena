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
      expect(state.aiContext, isNot(contains('tick-auth')));
      expect(state.aiContext, isNot(contains('(id:')));
      expect(state.retrievalResults.single.entityId, 'tick-auth');
      expect(state.retrievalError, isNull);
    });

    test('stores empty retrieval with honest no-match context signal',
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
      expect(
        state.aiContext,
        contains('No relevant workspace information was found'),
      );
      expect(state.aiContext, isNot(contains('queue_embedding')));
    });

    test('stores a user-safe retrieval error and unavailable context signal',
        () async {
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
      expect(
        state.aiContext,
        contains('Workspace retrieval was unavailable'),
      );
      expect(state.aiContext, isNot(contains('secret')));
      expect(state.retrievalError, 'Could not search workspace context.');
      expect(state.retrievalError, isNot(contains('secret')));
    });

    test('replaces retrieval results when a new query completes', () async {
      var call = 0;
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(
            RagRetriever(
              rpc: (functionName, {params}) async {
                if (functionName == 'queue_embedding') return ++call;
                if (call == 1) {
                  return [
                    {
                      'entity_type': 'task',
                      'entity_id': 'task-a',
                      'title': 'Query A task',
                      'content': 'A',
                      'similarity': 0.9,
                    },
                  ];
                }
                return [
                  {
                    'entity_type': 'ticket',
                    'entity_id': 'tick-b',
                    'title': 'Query B ticket',
                    'content': 'B',
                    'similarity': 0.91,
                  },
                ];
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await notifier.retrieveForQuery('first');
      expect(
        container.read(chatControllerProvider).retrievalResults.single.title,
        'Query A task',
      );

      await notifier.retrieveForQuery('second');
      final state = container.read(chatControllerProvider);
      expect(state.retrievalResults, hasLength(1));
      expect(state.retrievalResults.single.title, 'Query B ticket');
      expect(state.retrievalResults.single.entityId, 'tick-b');
      expect(state.aiContext, contains('Query B ticket'));
      expect(state.aiContext, isNot(contains('Query A task')));
      expect(state.aiContext, isNot(contains('tick-b')));
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
      expect(history.single['role'], 'model');
      expect(history.single['content'], contains('Ell-ena'));
      expect(
        history.any((message) => message['content'] == 'What about auth?'),
        isFalse,
      );
    });

    test('historyForAi maps user→user and assistant→model in order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(chatControllerProvider.notifier);

      notifier.addMessage(
        ChatMessage(
          text: 'First user',
          isUser: true,
          timestamp: DateTime(2026, 8, 11, 10),
        ),
      );
      notifier.addMessage(
        ChatMessage(
          text: 'First assistant',
          isUser: false,
          timestamp: DateTime(2026, 8, 11, 11),
        ),
      );
      notifier.addMessage(
        ChatMessage(
          text: 'Second user',
          isUser: true,
          timestamp: DateTime(2026, 8, 11, 12),
        ),
      );
      notifier.addMessage(
        ChatMessage(
          text: 'Second assistant',
          isUser: false,
          timestamp: DateTime(2026, 8, 11, 13),
        ),
      );
      notifier.addMessage(
        ChatMessage(
          text: 'Current user turn',
          isUser: true,
          timestamp: DateTime(2026, 8, 11, 14),
        ),
      );

      final history = notifier.historyForAi();

      expect(history, [
        {'role': 'user', 'content': 'First user'},
        {'role': 'model', 'content': 'First assistant'},
        {'role': 'user', 'content': 'Second user'},
        {'role': 'model', 'content': 'Second assistant'},
      ]);
      expect(
        history.any((m) => m['content'] == 'Current user turn'),
        isFalse,
      );
    });
  });
}
