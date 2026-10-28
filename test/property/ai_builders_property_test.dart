import 'dart:math';

import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/ai_context_builder.dart';
import 'package:ell_ena/services/ai_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/property.dart';

/// Ids that never occur in generated prose, so leaks are unambiguous.
String _uuid(Random r) =>
    'id-${List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join()}';

RagResult _result(Random r) {
  final type = Gens.oneOf(RagEntityType.values)(r);
  return RagResult(
    entityType: type,
    entityId: _uuid(r),
    title: Gens.word()(r),
    content: Gens.nullable(Gens.string(maxLength: 900))(r),
    status: Gens.nullable(Gens.oneOf(['todo', 'in_progress', 'open', '']))(r),
    priority: Gens.nullable(Gens.oneOf(['high', 'low', ' ']))(r),
    dueDate: Gens.nullable(Gens.dateTime())(r),
    meetingDate: Gens.nullable(Gens.dateTime())(r),
    similarity: r.nextDouble(),
  );
}

void main() {
  group('AiPromptBuilder.buildContents', () {
    final roles = Gens.oneOf(['user', 'model', 'assistant', 'system', 'tool']);

    property<List<Object>>(
      'wraps history between the system turn and the new message',
      (r) => [
        Gens.listOf(
          (r) => {'role': roles(r), 'content': Gens.string()(r)},
          maxLength: 12,
        )(r),
        Gens.string()(r),
        Gens.oneOf(['', '   ', 'Relevant workspace context:\nX'])(r),
      ],
      (input) {
        final history = (input[0] as List).cast<Map<String, String>>();
        final message = input[1] as String;
        final rag = input[2] as String;

        final contents = AiPromptBuilder.buildContents(
          userMessage: message,
          chatHistory: history,
          teamMembers: const [],
          ragContext: rag,
          now: DateTime(2026, 10, 22),
        );

        expect(contents, hasLength(history.length + 2));
        expect(contents.first['role'], 'model');
        expect(contents.last['parts'][0]['text'], message);
        expect(contents.last['role'], 'user');
        for (final turn in contents) {
          expect(const {'user', 'model'}, contains(turn['role']));
        }
        for (var i = 0; i < history.length; i++) {
          expect(contents[i + 1]['parts'][0]['text'], history[i]['content']);
        }
        final system = contents.first['parts'][0]['text'] as String;
        expect(system, contains('Current date: 2026-10-22'));
        expect(system.contains('Relevant workspace context'),
            rag.trim().isNotEmpty);
      },
    );

    property<String>(
      'tool follow-ups include RAG context only when it has content',
      Gens.oneOf(['', ' \n ', 'CTX-A', '  CTX-B  ']),
      (rag) {
        final text =
            AiPromptBuilder.buildToolFollowUpSystemText(ragContext: rag);

        expect(text, contains(AiPromptBuilder.workspaceGroundingRules));
        if (rag.trim().isNotEmpty) {
          expect(text.trimRight(), endsWith(rag.trim()));
        } else {
          expect(
              text.trimRight(),
              endsWith(
                  AiPromptBuilder.workspaceGroundingRules.split('\n').last));
        }
      },
    );
  });

  group('AiContextBuilder', () {
    property<List<RagResult>>(
      'workspace context never leaks entity ids and bounds every body',
      Gens.listOf(_result, maxLength: 6),
      (results) {
        final context = AiContextBuilder.buildWorkspaceContext(
            RagRetrievalOutcome.success(results));

        for (final result in results) {
          expect(context, isNot(contains(result.entityId)));
          expect(context, contains(result.title));
        }
        if (results.isEmpty) {
          expect(context, AiContextBuilder.emptyRetrievalContext);
        }
        for (final result in results) {
          final body = AiContextBuilder.formatResult(result);
          final longest = body
              .split('\n')
              .map((l) => l.length)
              .fold<int>(0, (a, b) => a > b ? a : b);
          // Title + label + truncated content ("Description: " + 600 + "…").
          expect(longest,
              lessThanOrEqualTo(AiContextBuilder.maxContentChars + 40));
        }
      },
      runs: 150,
    );

    property<String>(
      'status labels are title case words and stable when reapplied',
      Gens.string(alphabet: 'abcXYZ_ '),
      (raw) {
        final label = AiContextBuilder.formatStatusLabel(raw);

        expect(label, isNot(contains('_')));
        expect(AiContextBuilder.formatStatusLabel(label), label);
        for (final word in label.split(' ').where((w) => w.isNotEmpty)) {
          expect(word[0], word[0].toUpperCase());
          expect(word.substring(1), word.substring(1).toLowerCase());
        }
      },
      runs: 400,
    );

    property<List<Object>>(
      'tool summaries cap the rows, keep order, and leave input alone',
      (r) => [
        Gens.listOf(
          (r) => <String, dynamic>{
            'id': _uuid(r),
            'title': Gens.word()(r),
            'status': 'todo',
            'priority': 'low',
            'category': 'Bug',
            'secret_column': 'do not send',
            if (r.nextBool()) 'assignee': {'full_name': Gens.word()(r)},
          },
          maxLength: 30,
        )(r),
        Gens.intIn(-2, 25)(r),
      ],
      (input) {
        final rows = (input[0] as List).cast<Map<String, dynamic>>();
        final limit = input[1] as int;
        final before = rows.map((row) => Map.of(row)).toList();

        final tasks = AiContextBuilder.summarizeTasks(rows, limit: limit);
        final tickets = AiContextBuilder.summarizeTickets(rows, limit: limit);

        final expected = limit < 0 ? 0 : min(rows.length, limit);
        expect(tasks, hasLength(expected));
        expect(tickets, hasLength(expected));
        for (var i = 0; i < expected; i++) {
          expect(tasks[i]['id'], rows[i]['id']);
          expect(tickets[i]['id'], rows[i]['id']);
          expect(tasks[i].containsKey('secret_column'), isFalse);
          expect(tickets[i].containsKey('secret_column'), isFalse);
          expect(tasks[i].containsKey('assigned_to_name'),
              rows[i].containsKey('assignee'));
        }
        expect(rows, before);
      },
    );

    property<List<Map<String, dynamic>>>(
      'team context lists each member by name and role, without ids',
      Gens.listOf(
        (r) => <String, dynamic>{
          'id': _uuid(r),
          'full_name': Gens.nullable(Gens.word())(r),
          'role': Gens.nullable(Gens.oneOf(['admin', 'member']))(r),
        },
      ),
      (members) {
        final context = AiContextBuilder.buildTeamMemberContext(members);

        if (members.isEmpty) {
          expect(context, isEmpty);
          return;
        }
        final lines = context.trimRight().split('\n');
        expect(lines, hasLength(members.length + 1));
        for (var i = 0; i < members.length; i++) {
          final name = members[i]['full_name'] ?? 'Unknown';
          final role = members[i]['role'] ?? 'member';
          expect(lines[i + 1], '- $name ($role)');
          expect(context, isNot(contains(members[i]['id'] as String)));
        }
      },
    );
  });
}
