import 'package:flutter_test/flutter_test.dart';
import 'package:ell_ena/services/meeting_formatter.dart';

void main() {
  group('MeetingFormatter', () {
    group('formatMeetingSummary', () {
      test('formats complete summary correctly (Normal/valid input)', () {
        final Map<String, dynamic> summary = <String, dynamic>{
          'key_discussion_points': <String>['Point 1', 'Point 2'],
          'important_decisions': <String>['Decision 1'],
          'action_items': <Map<String, dynamic>>[
            <String, dynamic>{'item': 'Task 1', 'owner': 'Alice', 'deadline': 'Tomorrow'},
            <String, dynamic>{'item': 'Task 2'} // Missing owner and deadline to test fallbacks
          ],
          'follow_up_tasks': <String>['Follow up 1'],
          'overall_summary': 'Great meeting'
        };

        final String result = MeetingFormatter.formatMeetingSummary(
          title: 'Team Sync',
          date: '2026-07-25 at 10:00',
          summary: summary,
        );

        final String expected = '📅 *Team Sync*\n'
            '🕒 2026-07-25 at 10:00\n'
            '\n'
            'Key Points:\n'
            '-> Point 1\n'
            '-> Point 2\n'
            '\n'
            'Decisions:\n'
            '-> Decision 1\n'
            '\n'
            'Action Items:\n'
            '-> Task 1 (Owner: Alice, Deadline: Tomorrow)\n'
            '-> Task 2 (Owner: Unassigned, Deadline: No deadline)\n'
            '\n'
            'Follow-Up Tasks:\n'
            '-> Follow up 1\n'
            '\n'
            'Summary:\n'
            'Great meeting\n';

        expect(result, expected);
      });

      test('formats partial input correctly (Partial input)', () {
        final Map<String, dynamic> summary = <String, dynamic>{
          'key_discussion_points': <String>['Point 1'],
        };

        final String result = MeetingFormatter.formatMeetingSummary(
          title: 'Partial Sync',
          date: '2026-07-25 at 10:00',
          summary: summary,
        );

        final String expected = '📅 *Partial Sync*\n'
            '🕒 2026-07-25 at 10:00\n'
            '\n'
            'Key Points:\n'
            '-> Point 1\n'
            '\n';

        expect(result, expected);
      });

      test('formats empty summary map correctly (Empty input)', () {
        final String result = MeetingFormatter.formatMeetingSummary(
          title: 'Empty Sync',
          date: '2026-07-25 at 10:00',
          summary: <String, dynamic>{},
        );

        final String expected = '📅 *Empty Sync*\n'
            '🕒 2026-07-25 at 10:00\n'
            '\n';

        expect(result, expected);
      });

      test('formats null summary correctly (Null values)', () {
        final String result = MeetingFormatter.formatMeetingSummary(
          title: 'Null Sync',
          date: '2026-07-25 at 10:00',
          summary: null,
        );

        final String expected = '📅 *Null Sync*\n'
            '🕒 2026-07-25 at 10:00\n'
            '\n';

        expect(result, expected);
      });

      test('formats empty lists correctly (Empty lists/maps)', () {
        final Map<String, dynamic> summary = <String, dynamic>{
          'key_discussion_points': <String>[],
          'important_decisions': <String>[],
          'action_items': <Map<String, dynamic>>[],
          'follow_up_tasks': <String>[],
        };

        final String result = MeetingFormatter.formatMeetingSummary(
          title: 'Empty Lists Sync',
          date: '2026-07-25 at 10:00',
          summary: summary,
        );

        // Based on current implementation, empty key points and decisions generate headers,
        // but action items and follow up tasks are skipped due to .isNotEmpty check.
        final String expected = '📅 *Empty Lists Sync*\n'
            '🕒 2026-07-25 at 10:00\n'
            '\n'
            'Key Points:\n'
            '\n'
            'Decisions:\n'
            '\n';

        expect(result, expected);
      });

      test('throws Error when action items list contains null (Malformed input)', () {
        final Map<String, dynamic> summary = <String, dynamic>{
          'action_items': <dynamic>[null],
        };

        expect(
          () => MeetingFormatter.formatMeetingSummary(
            title: 'Malformed Sync',
            date: '2026-07-25 at 10:00',
            summary: summary,
          ),
          throwsA(isA<Error>()), // Catches NoSuchMethodError or TypeError depending on Dart version
        );
      });
    });

    group('formatMeetingSummaries', () {
      test('returns default message for empty list (Empty list)', () {
        final String result = MeetingFormatter.formatMeetingSummaries(<Map<String, dynamic>>[]);
        expect(result, 'No relevant meetings found.');
      });

      test('formats multiple meetings correctly (Multiple items, Date/String formatting)', () {
        final List<Map<String, dynamic>> meetings = <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Meeting 1',
            'meeting_date': '2026-07-25 14:30:00', // Use local string without Z to be completely safe from timezone parsing bugs
            'summary': <String, dynamic>{
              'overall_summary': 'Summary 1',
            },
          },
          <String, dynamic>{
            // Missing title and date
            'summary': null,
          }
        ];

        final String result = MeetingFormatter.formatMeetingSummaries(meetings);

        final String expected = '📅 *Meeting 1*\n'
            '🕒 2026-07-25 at 14:30\n'
            '\n'
            'Summary:\n'
            'Summary 1\n'
            '\n'
            '----------------------------------------\n'
            '\n'
            '📅 *Untitled Meeting*\n'
            '🕒 Unknown date\n'
            '\n';

        expect(result, expected);
      });

      test('throws FormatException for malformed date string (Edge cases)', () {
        final List<Map<String, dynamic>> meetings = <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Meeting 1',
            'meeting_date': 'not-a-valid-date', // Will fail DateTime.parse()
          }
        ];

        expect(
          () => MeetingFormatter.formatMeetingSummaries(meetings),
          throwsFormatException,
        );
      });
    });
  });
}
