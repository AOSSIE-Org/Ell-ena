/** Storage object path convention: {team_id}/{meeting_id}/{filename} */

export const MEETING_RECORDINGS_BUCKET = 'meeting-recordings' as const;

export type TranscriptionJobStatus =
  | 'pending'
  | 'processing'
  | 'completed'
  | 'failed';

export interface TranscriptionJob {
  id: string;
  meeting_id: string;
  audio_path: string;
  status: TranscriptionJobStatus;
  error_message: string | null;
  created_at: string;
  started_at: string | null;
  completed_at: string | null;
}

export interface TranscriptionJobInsert {
  meeting_id: string;
  audio_path: string;
  status?: TranscriptionJobStatus;
}

export interface TranscriptionJobUpdate {
  status?: TranscriptionJobStatus;
  error_message?: string | null;
  started_at?: string | null;
  completed_at?: string | null;
}

/** Builds a storage object path for a meeting recording. */
export function meetingRecordingPath(
  teamId: string,
  meetingId: string,
  filename: string,
): string {
  return `${teamId}/${meetingId}/${filename}`;
}
