/// Whether [meeting] is over: its end (start plus `duration_minutes`,
/// default 60) has passed, or it already has a transcript or summary.
/// A meeting that has started but not ended is not past.
bool isPastMeeting(Map<String, dynamic> meeting, DateTime now) {
  final start =
      DateTime.tryParse(meeting['meeting_date']?.toString() ?? '')?.toUtc();
  if (start == null) return false;
  final minutes = (meeting['duration_minutes'] as num?)?.toInt() ?? 60;
  final ended = !start.add(Duration(minutes: minutes)).isAfter(now.toUtc());

  final transcript = meeting['transcription']?.toString() ?? '';
  final summary = meeting['ai_summary']?.toString() ?? '';
  final hasRecord = transcript.isNotEmpty ||
      summary.isNotEmpty ||
      meeting['meeting_summary_json'] != null ||
      meeting['transcription_status'] == 'completed';

  return ended || hasRecord;
}
