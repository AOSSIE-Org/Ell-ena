import 'dart:convert';

import 'package:ell_ena/services/meeting_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fullSummary = <String, dynamic>{
    'key_discussion_points': ['Budget', 'Hiring'],
    'important_decisions': ['Ship v2 in November'],
    'action_items': [
      {'item': 'Draft plan', 'owner': 'Ada', 'deadline': 'Fri'},
      <String, dynamic>{},
    ],
    'follow_up_tasks': ['Book room'],
    'overall_summary': 'Productive.',
  };

  group('formatMeetingSummary', () {
    test('lays out every section in order', () {
      final text = MeetingFormatter.formatMeetingSummary(
        title: 'Planning',
        date: '2026-10-01 at 09:00',
        summary: fullSummary,
      );

      expect(
        text,
        '📅 *Planning*\n'
        '🕒 2026-10-01 at 09:00\n\n'
        'Key Points:\n-> Budget\n-> Hiring\n\n'
        'Decisions:\n-> Ship v2 in November\n\n'
        'Action Items:\n'
        '-> Draft plan (Owner: Ada, Deadline: Fri)\n'
        '-> No description (Owner: Unassigned, Deadline: No deadline)\n\n'
        'Follow-Up Tasks:\n-> Book room\n\n'
        'Summary:\nProductive.\n',
      );
    });

    test('skips missing and empty sections', () {
      final text = MeetingFormatter.formatMeetingSummary(
        title: 'Sync',
        date: 'today',
        summary: {'action_items': [], 'follow_up_tasks': []},
      );

      expect(text, '📅 *Sync*\n🕒 today\n\n');
    });

    test('prints only the header without a summary', () {
      expect(
        MeetingFormatter.formatMeetingSummary(
            title: 'T', date: 'D', summary: null),
        '📅 *T*\n🕒 D\n\n',
      );
    });
  });

  group('formatMeetingSummaries', () {
    test('says so when there are no meetings', () {
      expect(MeetingFormatter.formatMeetingSummaries([]),
          'No relevant meetings found.');
    });

    test('formats dates, defaults, and separators', () {
      final text = MeetingFormatter.formatMeetingSummaries([
        {
          'title': 'Retro',
          'meeting_date': '2026-03-04T05:06:00',
          'summary': {'overall_summary': 'Fine'},
        },
        {'meeting_date': null},
      ]);

      expect(text, contains('📅 *Retro*\n🕒 2026-03-04 at 05:06\n'));
      expect(text, contains('Summary:\nFine'));
      expect(text, contains('\n${'-' * 40}\n'));
      expect(text, contains('📅 *Untitled Meeting*\n🕒 Unknown date'));
      expect(text.indexOf('Retro'), lessThan(text.indexOf('Untitled')));
    });
  });

  group('formatRagResults', () {
    test('says so when nothing was retrieved', () {
      expect(
          MeetingFormatter.formatRagResults([]), 'No relevant context found.');
    });

    test('labels each entity type and shows similarity', () {
      final text = MeetingFormatter.formatRagResults([
        {
          'entity_type': 'meeting',
          'title': 'Kickoff',
          'content': jsonEncode({'overall_summary': 'Started'}),
          'similarity': 0.91,
        },
        {'entity_type': 'meeting', 'title': 'Notes', 'content': 'raw notes'},
        {'entity_type': 'meeting', 'title': 'Blank', 'content': '  '},
        {'entity_type': 'task', 'title': 'Fix bug', 'content': 'details'},
        {'entity_type': 'task', 'title': 'Bare task'},
        {'entity_type': 'ticket', 'title': 'Crash', 'content': 'stack'},
        {'entity_type': 'ticket', 'title': 'Bare ticket', 'content': ''},
        {'entity_type': 'doc', 'title': 'Wiki', 'content': 'page'},
        {'content': null},
      ]);

      expect(text, contains('📅 *Kickoff*\n🕒 Retrieved meeting'));
      expect(text, contains('Summary:\nStarted'));
      expect(text, contains('(similarity: 0.91)'));
      expect(text, contains('📅 *Meeting: Notes*\nraw notes'));
      expect(text, contains('📅 *Meeting: Blank*\n'));
      expect(text, contains('✅ *Task: Fix bug*\ndetails'));
      expect(text, contains('✅ *Task: Bare task*\n'));
      expect(text, contains('🎫 *Ticket: Crash*\nstack'));
      expect(text, contains('*Wiki* (doc)\npage'));
      expect(text, contains('*Untitled* (unknown)'));
      expect(RegExp('-{40}').allMatches(text), hasLength(8));
    });
  });

  group('tryParseMeetingSummary', () {
    test('accepts maps and JSON object strings', () {
      expect(MeetingFormatter.tryParseMeetingSummary({'a': 1}), {'a': 1});
      expect(MeetingFormatter.tryParseMeetingSummary(<Object, Object>{'a': 1}),
          {'a': 1});
      expect(MeetingFormatter.tryParseMeetingSummary('{"a":1}'), {'a': 1});
    });

    test('rejects everything else', () {
      for (final value in [null, '', '   ', 'not json', '[1,2]', '3', 42]) {
        expect(MeetingFormatter.tryParseMeetingSummary(value), isNull,
            reason: '$value');
      }
    });
  });
}
