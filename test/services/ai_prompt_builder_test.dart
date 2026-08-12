import 'package:ell_ena/services/ai_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPromptBuilder', () {
    final teamMembers = [
      {'id': 'u-1', 'full_name': 'Aarav', 'role': 'admin'},
    ];

    test('keeps team, date, history, and guidelines when RAG is empty', () {
      final contents = AiPromptBuilder.buildContents(
        userMessage: 'Create a task for tomorrow',
        chatHistory: [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi, how can I help?'},
        ],
        teamMembers: teamMembers,
        ragContext: '',
        now: DateTime(2026, 8, 11),
      );

      final systemText = contents.first['parts'][0]['text'] as String;
      expect(systemText, contains('Current date: 2026-08-11'));
      expect(systemText, contains('Aarav'));
      expect(systemText, contains('u-1'));
      expect(
          systemText, contains('Guidelines for tasks, tickets, and meetings'));
      expect(systemText, contains('query_tasks'));
      expect(systemText, isNot(contains('Relevant workspace context')));
      expect(systemText, isNot(contains('Order office snacks')));

      expect(contents[1]['parts'][0]['text'], 'Hello');
      expect(contents.last['parts'][0]['text'], 'Create a task for tomorrow');
    });

    test('injects only the provided targeted RAG context', () {
      const ragContext =
          'Relevant workspace context:\n\nTicket: OAuth redirect broken (id: tick-auth)\n';

      final contents = AiPromptBuilder.buildContents(
        userMessage: 'What did we discuss about the authentication issue?',
        chatHistory: const [],
        teamMembers: teamMembers,
        ragContext: ragContext,
        now: DateTime(2026, 8, 11),
      );

      final systemText = contents.first['parts'][0]['text'] as String;
      expect(systemText, contains('OAuth redirect broken'));
      expect(systemText, contains('tick-auth'));
      expect(systemText, isNot(contains('Order office snacks')));
    });
  });
}
