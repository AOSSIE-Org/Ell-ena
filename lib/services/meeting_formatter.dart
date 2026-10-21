// Pure Dart utility class for formatting meeting summaries and RAG results
import 'dart:convert';

/// Helper class to format meeting summaries for better display in chat
class MeetingFormatter {
  /// Formats a meeting summary with improved styling for chat display
  static String formatMeetingSummary({
    required String title,
    required String date,
    required Map<String, dynamic>? summary,
  }) {
    final buffer = StringBuffer();

    // Format header with title and date
    buffer.writeln('📅 *$title*');
    buffer.writeln('🕒 $date\n');

    if (summary != null) {
      // Add key points section with bullet points
      if (summary['key_discussion_points'] != null) {
        buffer.writeln('Key Points:');
        for (var point in summary['key_discussion_points']) {
          buffer.writeln('-> $point');
        }
        buffer.writeln('');
      }

      // Add decisions section with bullet points
      if (summary['important_decisions'] != null) {
        buffer.writeln('Decisions:');
        for (var decision in summary['important_decisions']) {
          buffer.writeln('-> $decision');
        }
        buffer.writeln('');
      }

      // Add action items
      if (summary['action_items'] != null &&
          summary['action_items'].isNotEmpty) {
        buffer.writeln('Action Items:');
        for (var item in summary['action_items']) {
          final task = item['item'] ?? 'No description';
          final owner = item['owner'] ?? 'Unassigned';
          final deadline = item['deadline'] ?? 'No deadline';
          buffer.writeln('-> $task (Owner: $owner, Deadline: $deadline)');
        }
        buffer.writeln('');
      }

      // Add follow-up tasks
      if (summary['follow_up_tasks'] != null &&
          summary['follow_up_tasks'].isNotEmpty) {
        buffer.writeln('Follow-Up Tasks:');
        for (var task in summary['follow_up_tasks']) {
          buffer.writeln('-> $task');
        }
        buffer.writeln('');
      }

      // Add overall summary if available
      if (summary['overall_summary'] != null) {
        buffer.writeln('Summary:');
        buffer.writeln('${summary['overall_summary']}');
      }
    }

    return buffer.toString();
  }

  /// Formats a list of meeting summaries for chat display
  static String formatMeetingSummaries(List<Map<String, dynamic>> meetings) {
    if (meetings.isEmpty) {
      return "No relevant meetings found.";
    }

    final buffer = StringBuffer();

    for (int i = 0; i < meetings.length; i++) {
      final meeting = meetings[i];

      // Add separator between meetings
      if (i > 0) {
        buffer.writeln('\n${'-' * 40}\n');
      }

      // Format meeting date
      final meetingDate = meeting['meeting_date'] != null
          ? DateTime.parse(meeting['meeting_date'].toString())
          : null;
      final dateStr = meetingDate != null
          ? '${meetingDate.year}-${meetingDate.month.toString().padLeft(2, '0')}-${meetingDate.day.toString().padLeft(2, '0')} at ${meetingDate.hour.toString().padLeft(2, '0')}:${meetingDate.minute.toString().padLeft(2, '0')}'
          : "Unknown date";

      // Format the individual meeting
      buffer.write(formatMeetingSummary(
        title: meeting['title'] ?? 'Untitled Meeting',
        date: dateStr,
        summary: meeting['summary'],
      ));
    }

    return buffer.toString();
  }

  /// Formats rag_search / search_rag_by_resp_id rows for the Gemini prompt.
  /// Reuses meeting formatting when content is meeting summary JSON.
  static String formatRagResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return "No relevant context found.";
    }

    final buffer = StringBuffer();

    for (int i = 0; i < results.length; i++) {
      final result = results[i];

      if (i > 0) {
        buffer.writeln('\n${'-' * 40}\n');
      }

      final entityType = result['entity_type']?.toString() ?? 'unknown';
      final title = result['title']?.toString() ?? 'Untitled';
      final content = result['content'];
      final similarity = result['similarity'];

      if (entityType == 'meeting') {
        final summary = tryParseMeetingSummary(content);
        if (summary != null) {
          buffer.write(formatMeetingSummary(
            title: title,
            date: 'Retrieved meeting',
            summary: summary,
          ));
        } else {
          buffer.writeln('📅 *Meeting: $title*');
          if (content != null && content.toString().trim().isNotEmpty) {
            buffer.writeln(content.toString());
          }
        }
      } else if (entityType == 'task') {
        buffer.writeln('✅ *Task: $title*');
        if (content != null && content.toString().trim().isNotEmpty) {
          buffer.writeln(content.toString());
        }
      } else if (entityType == 'ticket') {
        buffer.writeln('🎫 *Ticket: $title*');
        if (content != null && content.toString().trim().isNotEmpty) {
          buffer.writeln(content.toString());
        }
      } else {
        buffer.writeln('*$title* ($entityType)');
        if (content != null && content.toString().trim().isNotEmpty) {
          buffer.writeln(content.toString());
        }
      }

      if (similarity != null) {
        buffer.writeln('(similarity: $similarity)');
      }
    }

    return buffer.toString();
  }

  static Map<String, dynamic>? tryParseMeetingSummary(dynamic content) {
    if (content == null) return null;
    if (content is Map<String, dynamic>) return content;
    if (content is Map) return Map<String, dynamic>.from(content);
    if (content is String && content.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
