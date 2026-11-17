import 'package:flutter_test/flutter_test.dart';

import 'package:ell_ena/services/meeting_duration.dart';

void main() {
  group('meetingDurationMinutes', () {
    test('uses the stored whole-minute duration', () {
      expect(meetingDurationMinutes({'duration_minutes': 90}), 90);
    });

    test('accepts a JSON-decoded double', () {
      expect(meetingDurationMinutes({'duration_minutes': 90.0}), 90);
    });

    test('uses the default for missing or invalid values', () {
      expect(meetingDurationMinutes({}), defaultMeetingDurationMinutes);
      expect(
        meetingDurationMinutes({'duration_minutes': '90'}),
        defaultMeetingDurationMinutes,
      );
      expect(
        meetingDurationMinutes({'duration_minutes': 0}),
        defaultMeetingDurationMinutes,
      );
      expect(
        meetingDurationMinutes({'duration_minutes': -30}),
        defaultMeetingDurationMinutes,
      );
      expect(
        meetingDurationMinutes({'duration_minutes': double.nan}),
        defaultMeetingDurationMinutes,
      );
    });
  });
}
