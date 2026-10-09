import 'package:intl/intl.dart';

import 'package:ell_ena/services/ai_context_builder.dart';

/// Assembles Gemini `contents` for a chat turn.
///
/// Non-RAG context (identity, date, team, history, guidelines) is always
/// included. Targeted RAG context is appended only when [ragContext] is
/// non-empty.
class AiPromptBuilder {
  static List<Map<String, dynamic>> buildContents({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
    required List<Map<String, dynamic>> teamMembers,
    String ragContext = '',
    DateTime? now,
  }) {
    final contents = <Map<String, dynamic>>[];
    final teamMemberContext =
        AiContextBuilder.buildTeamMemberContext(teamMembers);
    final date = DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

    final systemText = StringBuffer()
      ..writeln(
        'You are a helpful assistant for a team collaboration app called Ell-ena. '
        'You can help users create and manage tasks, tickets, and schedule meetings. '
        'When appropriate, call the relevant function to help users.',
      )
      ..writeln()
      ..writeln('Current date: $date')
      ..writeln();

    if (teamMemberContext.isNotEmpty) {
      systemText.writeln(teamMemberContext);
      systemText.writeln();
    }

    if (ragContext.trim().isNotEmpty) {
      systemText.writeln(ragContext.trim());
      systemText.writeln();
    }

    systemText
      ..writeln('Guidelines for tasks, tickets, and meetings:')
      ..writeln(
        '1. Create descriptive, clear titles that summarize the purpose - be specific and professional (e.g., \'Bug Fixes Discussion\' instead of just \'Meeting\')',
      )
      ..writeln(
        '2. Always provide detailed descriptions with all relevant information, even if the user doesn\'t explicitly provide it',
      )
      ..writeln(
        '3. When users mention dates like \'tomorrow\', \'next week\', etc., convert them to proper ISO format (YYYY-MM-DD for tasks, YYYY-MM-DDTHH:MM:SS for meetings)',
      )
      ..writeln(
        '4. For tickets, choose the appropriate priority and category based on the request context',
      )
      ..writeln(
        '5. If the user doesn\'t specify who to assign the task/ticket to, leave it unassigned',
      )
      ..writeln(
        '6. If the user mentions a team member by name, assign it to that person - be attentive to names mentioned in the request',
      )
      ..writeln(
        '7. When users ask about tasks assigned to specific team members (e.g., \'tasks assigned to Aarav\'), use query_tasks with assigned_to_team_member parameter',
      )
      ..writeln(
        '8. When users ask about their own tasks, use query_tasks with assigned_to_me=true',
      )
      ..writeln(
        '9. When users ask to modify existing items, use the modify_item function',
      )
      ..writeln(
        '10. Be proactive in suggesting appropriate actions based on user requests',
      )
      ..writeln(
        '11. For meetings, always set appropriate titles and descriptions based on the context, even if minimal information is provided',
      )
      ..writeln(
        '12. Be very attentive to team member names in requests to ensure proper assignment and querying',
      )
      ..writeln(
        '13. Use the relevant workspace context when it answers the user. If none is provided, answer from the conversation and tools — do not invent workspace records.',
      );

    contents.add({
      'role': 'model',
      'parts': [
        {'text': systemText.toString()},
      ],
    });

    for (final message in chatHistory) {
      var role = message['role'] ?? 'user';
      if (role != 'user' && role != 'model') {
        role = 'user';
      }
      contents.add({
        'role': role,
        'parts': [
          {'text': message['content'] ?? ''},
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    return contents;
  }
}
