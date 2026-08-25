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
          // Expanded JSON can exceed task/ticket limits; cap after format.
          buffer.write(_truncate(MeetingFormatter.formatMeetingSummary(
            title: '${result.title}$idSuffix',
            date: _meetingDateLabel(result),
            summary: summary,
          )));
        } else {
          buffer.writeln('Meeting: ${result.title}$idSuffix');
          final text = _truncate(result.content);
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
        break;
      case RagEntityType.task:
        buffer.writeln('Task: ${result.title}$idSuffix');
        final text = _truncate(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
      case RagEntityType.ticket:
        buffer.writeln('Ticket: ${result.title}$idSuffix');
        final text = _truncate(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
      case RagEntityType.unknown:
        buffer.writeln('${result.title}$idSuffix');
        final text = _truncate(result.content);
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

  /// Max rows included in tool follow-up payloads sent to Gemini.
  static const int maxToolResults = 20;

  /// Compact tool payload so Gemini does not receive full database rows.
  /// Caps to [maxToolResults] without mutating [tasks].
  static List<Map<String, dynamic>> summarizeTasks(
    List<Map<String, dynamic>> tasks, {
    int limit = maxToolResults,
  }) {
    return _capToolResults(tasks, limit).map(summarizeTask).toList();
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

  /// Compact tool payload so Gemini does not receive full database rows.
  /// Caps to [maxToolResults] without mutating [tickets].
  static List<Map<String, dynamic>> summarizeTickets(
    List<Map<String, dynamic>> tickets, {
    int limit = maxToolResults,
  }) {
    return _capToolResults(tickets, limit).map(summarizeTicket).toList();
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

  /// Returns at most [limit] leading items; never mutates [items].
  static List<Map<String, dynamic>> _capToolResults(
    List<Map<String, dynamic>> items,
    int limit,
  ) {
    if (limit < 0) return const [];
    if (items.length <= limit) return items;
    return items.sublist(0, limit);
  }

  static String _meetingDateLabel(RagResult result) {
    final date = result.meetingDate;
    if (date == null) return 'Retrieved meeting';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d at $hh:$mm';
  }

  static String _truncate(String? content) {
    if (content == null) return '';
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxContentChars) return trimmed;
    return '${trimmed.substring(0, maxContentChars)}…';
  }
}
