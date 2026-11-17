/// Default meeting length when a stored meeting has no usable duration.
const int defaultMeetingDurationMinutes = 60;

/// Returns a safe positive whole-minute duration for a stored meeting.
///
/// Supabase/JSON may decode numeric values as [int] or [double], so the raw
/// value is accepted as any finite [num]. Missing, non-numeric, non-finite,
/// zero and negative values fall back to [defaultMeetingDurationMinutes].
int meetingDurationMinutes(Map<String, dynamic> meeting) {
  final raw = meeting['duration_minutes'];
  if (raw is num && raw.isFinite && raw > 0) {
    return raw.toInt();
  }
  return defaultMeetingDurationMinutes;
}
