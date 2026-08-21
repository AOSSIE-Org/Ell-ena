import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/meeting_formatter.dart';

/// Builds deterministic, inspectable Gemini context from retrieval results.
///
/// Only the provided [RagResult]s are included — callers must not pass
/// full task/ticket/meeting lists.
class AiContextBuilder {
  static const int maxContentChars = 600;

  /// Workspace block injected into the system prompt. Empty when there is
  /// nothing safe/useful to add (empty or failed retrieval).
  static String buildWorkspaceContext(RagRetrievalOutcome outcome) {
    if (!outcome.hasResults) {
      return '';
    }
    return 'Relevant workspace context:\n\n${formatResults(outcome.results)}';
  }

  static String formatResults(List<RagResult> results) {
    if (results.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      if (i > 0) {
        buffer.writeln('\n${'-' * 40}\n');
      }
      buffer.write(formatResult(results[i]));
    }
    return buffer.toString();
  }

  static String formatResult(RagResult result) {
    final buffer = StringBuffer();
    final idSuffix =
        result.entityId.isNotEmpty ? ' (id: ${result.entityId})' : '';

    switch (result.entityType) {
      case RagEntityType.meeting:
        final summary = MeetingFormatter.tryParseMeetingSummary(result.content);
        if (summary != null) {
          buffer.write(MeetingFormatter.formatMeetingSummary(
            title: '${result.title}$idSuffix',
            date: 'Retrieved meeting',
            summary: summary,
          ));
        } else {
          buffer.writeln('Meeting: ${result.title}$idSuffix');
          final text = _truncated(result.content);
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
        break;
      case RagEntityType.task:
        buffer.writeln('Task: ${result.title}$idSuffix');
        final text = _truncated(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
      case RagEntityType.ticket:
        buffer.writeln('Ticket: ${result.title}$idSuffix');
        final text = _truncated(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
      case RagEntityType.unknown:
        buffer.writeln('${result.title}$idSuffix');
        final text = _truncated(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
    }

    return buffer.toString();
  }

  static String buildTeamMemberContext(List<Map<String, dynamic>> teamMembers) {
    if (teamMembers.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('Available team members:\n');
    for (final member in teamMembers) {
      final name = member['full_name'] ?? 'Unknown';
      final role = member['role'] ?? 'member';
      final id = member['id'] ?? '';
      buffer.writeln('- $name ($role): $id');
    }
    return buffer.toString();
  }

  /// Compact tool payload so Gemini does not receive full database rows.
  static List<Map<String, dynamic>> summarizeTasks(
    List<Map<String, dynamic>> tasks,
  ) {
    return tasks.map(summarizeTask).toList();
  }

  static Map<String, dynamic> summarizeTask(Map<String, dynamic> task) {
    final assignee = task['assignee'];
    return {
      'id': task['id'],
      'title': task['title'],
      'status': task['status'],
      'due_date': task['due_date'],
      'assigned_to': task['assigned_to'],
      if (assignee is Map && assignee['full_name'] != null)
        'assigned_to_name': assignee['full_name'],
    };
  }

  static List<Map<String, dynamic>> summarizeTickets(
    List<Map<String, dynamic>> tickets,
  ) {
    return tickets.map(summarizeTicket).toList();
  }

  static Map<String, dynamic> summarizeTicket(Map<String, dynamic> ticket) {
    final assignee = ticket['assignee'];
    return {
      'id': ticket['id'],
      'title': ticket['title'],
      'status': ticket['status'],
      'priority': ticket['priority'],
      'category': ticket['category'],
      'assigned_to': ticket['assigned_to'],
      if (assignee is Map && assignee['full_name'] != null)
        'assigned_to_name': assignee['full_name'],
    };
  }

  static String _truncated(String? content) {
    if (content == null) return '';
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxContentChars) return trimmed;
    return '${trimmed.substring(0, maxContentChars)}…';
  }
}
