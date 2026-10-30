import 'package:ell_ena/utils/meeting_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);

  Map<String, dynamic> meeting(
    DateTime start, {
    int? duration,
    Map<String, dynamic> extra = const {},
  }) =>
      {
        'meeting_date': start.toIso8601String(),
        if (duration != null) 'duration_minutes': duration,
        ...extra,
      };

  test('a future meeting is not past', () {
    expect(isPastMeeting(meeting(now.add(const Duration(hours: 1))), now),
        isFalse);
  });

  test('a meeting in progress is not past', () {
    final start = now.subtract(const Duration(minutes: 20));
    expect(isPastMeeting(meeting(start, duration: 30), now), isFalse);
  });

  test('a meeting is past once its duration is over', () {
    final start = now.subtract(const Duration(minutes: 30));
    expect(isPastMeeting(meeting(start, duration: 30), now), isTrue);
  });

  test('duration defaults to 60 minutes', () {
    expect(
        isPastMeeting(meeting(now.subtract(const Duration(minutes: 59))), now),
        isFalse);
    expect(
        isPastMeeting(meeting(now.subtract(const Duration(minutes: 60))), now),
        isTrue);
  });

  test('a transcript or summary marks a meeting as past early', () {
    final start = now.subtract(const Duration(minutes: 5));
    for (final extra in <Map<String, dynamic>>[
      {'transcription': 'Hello'},
      {'ai_summary': 'Done'},
      {'meeting_summary_json': <String, dynamic>{}},
      {'transcription_status': 'completed'},
    ]) {
      expect(isPastMeeting(meeting(start, extra: extra), now), isTrue,
          reason: '$extra');
    }
  });

  test('compares local and UTC times correctly', () {
    final localStart = now.toLocal().add(const Duration(minutes: 10));
    expect(isPastMeeting(meeting(localStart), now), isFalse);
  });

  test('a missing or invalid date is not past', () {
    expect(isPastMeeting({'meeting_date': null}, now), isFalse);
    expect(isPastMeeting({'meeting_date': 'soon'}, now), isFalse);
  });
}
