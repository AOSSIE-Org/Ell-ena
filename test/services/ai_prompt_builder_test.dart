import 'package:ell_ena/services/ai_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPromptBuilder', () {
    final teamMembers = [
      {'id': 'u-1', 'full_name': 'Aarav', 'role': 'admin'},
    ];

    test('keeps team, date, history, guidelines, and grounding when RAG empty',
        () {
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
      expect(systemText, isNot(contains('u-1')));
      expect(
          systemText, contains('Guidelines for tasks, tickets, and meetings'));
      expect(systemText, contains('query_tasks'));
      expect(systemText, contains('Workspace grounding:'));
      expect(systemText, contains('Do not invent'));
      expect(
        systemText,
        contains('Never expose internal database IDs or UUIDs'),
      );
      expect(
        systemText,
        contains('could not find enough information'),
      );
      expect(systemText, isNot(contains('Order office snacks')));

      expect(contents[1]['role'], 'user');
      expect(contents[1]['parts'][0]['text'], 'Hello');
      expect(contents[2]['role'], 'model');
      expect(contents[2]['parts'][0]['text'], 'Hi, how can I help?');
      expect(contents.last['role'], 'user');
      expect(contents.last['parts'][0]['text'], 'Create a task for tomorrow');
    });

    test('maps history roles to Gemini user/model and preserves order', () {
      final contents = AiPromptBuilder.buildContents(
        userMessage: 'Follow up',
        chatHistory: [
          {'role': 'user', 'content': 'Alpha'},
          {'role': 'model', 'content': 'Beta'},
          {'role': 'assistant', 'content': 'Gamma'},
        ],
        teamMembers: const [],
        ragContext: '',
        now: DateTime(2026, 8, 11),
      );

      expect(contents[1]['role'], 'user');
      expect(contents[1]['parts'][0]['text'], 'Alpha');
      expect(contents[2]['role'], 'model');
      expect(contents[2]['parts'][0]['text'], 'Beta');
      expect(contents[3]['role'], 'model');
      expect(contents[3]['parts'][0]['text'], 'Gamma');
      expect(contents[4]['role'], 'user');
      expect(contents[4]['parts'][0]['text'], 'Follow up');
    });

    test('injects only the provided targeted RAG context without echoing IDs',
        () {
      const ragContext =
          'Relevant workspace context:\n\nTICKET\nTitle: OAuth redirect broken\nStatus: Open\n';

      final contents = AiPromptBuilder.buildContents(
        userMessage: 'What did we discuss about the authentication issue?',
        chatHistory: const [],
        teamMembers: teamMembers,
        ragContext: ragContext,
        now: DateTime(2026, 8, 11),
      );

      final systemText = contents.first['parts'][0]['text'] as String;
      expect(systemText, contains('OAuth redirect broken'));
      expect(systemText, contains('Workspace grounding:'));
      expect(systemText, isNot(contains('tick-auth')));
      expect(systemText, isNot(contains('(id:')));
      expect(systemText, isNot(contains('Order office snacks')));
    });

    test('tool follow-up system text keeps grounding and optional RAG', () {
      final text = AiPromptBuilder.buildToolFollowUpSystemText(
        ragContext:
            'Relevant workspace context:\nNo relevant workspace information was found for this query.',
      );

      expect(text, contains('Workspace grounding:'));
      expect(text, contains('Never expose internal database IDs'));
      expect(text, contains('No relevant workspace information'));
      expect(text, isNot(contains('queue_embedding')));
    });
  });
}
