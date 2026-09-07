import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/meeting_formatter.dart';
import 'package:intl/intl.dart';

/// Builds deterministic, inspectable Gemini context from retrieval results.
///
/// Only the provided [RagResult]s are included — callers must not pass
/// full task/ticket/meeting lists.
///
/// [RagResult.entityId] is kept on the model for navigation/tools but is
/// never written into natural-language context strings.
class AiContextBuilder {
  static const int maxContentChars = 600;

  static const String emptyRetrievalContext =
      'Relevant workspace context:\n'
      'No relevant workspace information was found for this query.';

  static const String failedRetrievalContext =
      'Relevant workspace context:\n'
      'Workspace retrieval was unavailable for this request.';

  /// Workspace block injected into the system prompt.
  ///
  /// Always returns a non-empty signal so Gemini knows whether retrieval
  /// succeeded, returned nothing useful, or failed.
  static String buildWorkspaceContext(RagRetrievalOutcome outcome) {
    if (outcome.status == RagRetrievalStatus.error) {
      return failedRetrievalContext;
    }
    if (outcome.status == RagRetrievalStatus.empty || !outcome.hasResults) {
      return emptyRetrievalContext;
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

    switch (result.entityType) {
      case RagEntityType.meeting:
        buffer.writeln('MEETING');
        buffer.writeln('Title: ${result.title}');
        final dateLabel = _meetingDateLabel(result);
        if (dateLabel != 'Retrieved meeting') {
          buffer.writeln('Date: $dateLabel');
        }
        final summary = MeetingFormatter.tryParseMeetingSummary(result.content);
        if (summary != null) {
          final formatted = MeetingFormatter.formatMeetingSummary(
            title: result.title,
            date: dateLabel,
            summary: summary,
          );
          // Drop the formatter's header (title/date already printed) when possible.
          final body = _meetingSummaryBody(formatted, result.title, dateLabel);
          final text = _truncate(body.isNotEmpty ? body : formatted);
          if (text.isNotEmpty) {
            buffer.writeln('Summary:');
            buffer.writeln(text);
          }
        } else {
          final text = _truncate(result.content);
          if (text.isNotEmpty) {
            buffer.writeln('Summary:');
            buffer.writeln(text);
          }
        }
        break;
      case RagEntityType.task:
        buffer.writeln('TASK');
        buffer.writeln('Title: ${result.title}');
        if (result.status != null && result.status!.trim().isNotEmpty) {
          buffer.writeln('Status: ${formatStatusLabel(result.status!)}');
        }
        if (result.dueDate != null) {
          buffer.writeln('Due: ${_formatDueDate(result.dueDate!)}');
        }
        final text = _truncate(result.content);
        if (text.isNotEmpty) {
          buffer.writeln('Description: $text');
        }
        break;
      case RagEntityType.ticket:
        buffer.writeln('TICKET');
        buffer.writeln('Title: ${result.title}');
        if (result.status != null && result.status!.trim().isNotEmpty) {
          buffer.writeln('Status: ${formatStatusLabel(result.status!)}');
        }
        if (result.priority != null && result.priority!.trim().isNotEmpty) {
          buffer.writeln('Priority: ${formatStatusLabel(result.priority!)}');
        }
        final text = _truncate(result.content);
        if (text.isNotEmpty) {
          buffer.writeln('Description: $text');
        }
        break;
      case RagEntityType.unknown:
        buffer.writeln(result.title);
        final text = _truncate(result.content);
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
        break;
    }

    return buffer.toString();
  }

  /// Human-readable labels for status/priority (e.g. in_progress → In Progress).
  static String formatStatusLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String buildTeamMemberContext(List<Map<String, dynamic>> teamMembers) {
    if (teamMembers.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('Available team members:\n');
    for (final member in teamMembers) {
      final name = member['full_name'] ?? 'Unknown';
      final role = member['role'] ?? 'member';
      // Names/roles only — do not put member UUIDs in natural-language context.
      buffer.writeln('- $name ($role)');
    }
    return buffer.toString();
  }

  /// Max rows included in tool follow-up payloads sent to Gemini.
  static const int maxToolResults = 20;

  /// Compact tool payload so Gemini does not receive full database rows.
  /// Caps to [maxToolResults] without mutating [tasks].
  ///
  /// Structured [id] fields remain for tool operations; the system prompt
  /// instructs the model not to repeat them in prose.
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

  static String _formatDueDate(DateTime date) {
    return DateFormat.yMMMMd().format(date.toLocal());
  }

  /// Prefer summary sections after the emoji header lines from [MeetingFormatter].
  static String _meetingSummaryBody(
    String formatted,
    String title,
    String dateLabel,
  ) {
    final lines = formatted.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (kept.isNotEmpty) kept.add('');
        continue;
      }
      // Skip formatter header lines that duplicate Title/Date.
      if (trimmed.contains(title) &&
          (trimmed.startsWith('📅') || trimmed.startsWith('*'))) {
        continue;
      }
      if (trimmed.startsWith('🕒')) continue;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  static String _truncate(String? content) {
    if (content == null) return '';
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxContentChars) return trimmed;
    return '${trimmed.substring(0, maxContentChars)}…';
  }
}
