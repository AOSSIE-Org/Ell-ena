#!/usr/bin/env python3
"""Poll transcription_jobs and write meetings.transcription for the existing trigger pipeline."""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

from faster_whisper import WhisperModel
from supabase import Client, create_client

from config import WorkerConfig

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("faster-whisper-worker")

DEFAULT_SPEAKER = "Speaker"


def create_supabase_client(config: WorkerConfig) -> Client:
    return create_client(config.supabase_url, config.supabase_service_role_key)


def claim_next_job(client: Client) -> dict | None:
    """Atomically claim the oldest pending job."""
    pending = (
        client.table("transcription_jobs")
        .select("*")
        .eq("status", "pending")
        .order("created_at")
        .limit(1)
        .execute()
    )

    if not pending.data:
        return None

    job = pending.data[0]
    now = datetime.now(timezone.utc).isoformat()

    claimed = (
        client.table("transcription_jobs")
        .update({"status": "processing", "started_at": now})
        .eq("id", job["id"])
        .eq("status", "pending")
        .execute()
    )

    if not claimed.data:
        logger.debug("Job %s was claimed by another worker", job["id"])
        return None

    return claimed.data[0]


def download_audio(client: Client, config: WorkerConfig, audio_path: str) -> Path:
    suffix = Path(audio_path).suffix or ".audio"
    data = client.storage.from_(config.bucket_name).download(audio_path)

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    try:
        tmp.write(data)
        tmp.flush()
        return Path(tmp.name)
    finally:
        tmp.close()


def transcribe_audio(
    local_audio: Path,
    config: WorkerConfig,
    model: WhisperModel,
) -> list[dict[str, str]]:
    """Run faster-whisper and map segments to the Vexa-compatible shape."""
    segments, _info = model.transcribe(str(local_audio), beam_size=5)

    result: list[dict[str, str]] = []
    for segment in segments:
        text = segment.text.strip()
        if not text:
            continue
        result.append({"speaker": DEFAULT_SPEAKER, "text": text})

    if not result:
        raise ValueError("Transcription produced no text segments")

    return result


def build_transcription_payload(segments: list[dict[str, str]]) -> str:
    """
    meetings.transcription must be JSON text with a top-level `segments` array.
    extract_clean_transcription() reads seg->>'speaker' and seg->>'text' from it.
    """
    return json.dumps({"segments": segments}, ensure_ascii=False)


def write_meeting_transcription(
    client: Client,
    meeting_id: str,
    transcription: str,
) -> None:
    now = datetime.now(timezone.utc).isoformat()
    response = (
        client.table("meetings")
        .update(
            {
                "transcription": transcription,
                "transcription_attempted_at": now,
            }
        )
        .eq("id", meeting_id)
        .execute()
    )

    if not response.data:
        raise RuntimeError(f"Meeting {meeting_id} was not updated")


def mark_job_completed(client: Client, job_id: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    client.table("transcription_jobs").update(
        {
            "status": "completed",
            "completed_at": now,
            "error_message": None,
        }
    ).eq("id", job_id).execute()


def mark_job_failed(client: Client, job_id: str, error: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    client.table("transcription_jobs").update(
        {
            "status": "failed",
            "completed_at": now,
            "error_message": error[:2000],
        }
    ).eq("id", job_id).execute()


def reset_job_to_pending(client: Client, job_id: str) -> None:
    client.table("transcription_jobs").update(
        {
            "status": "pending",
            "started_at": None,
        }
    ).eq("id", job_id).eq("status", "processing").execute()


def recover_stuck_jobs(client: Client, *, timeout_seconds: int) -> int:
    """Re-queue processing jobs whose worker died or hung past the timeout."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=timeout_seconds)
    stuck = (
        client.table("transcription_jobs")
        .select("id, started_at, created_at")
        .eq("status", "processing")
        .execute()
    )

    recovered = 0
    for job in stuck.data or []:
        marker_raw = job.get("started_at") or job.get("created_at")
        if marker_raw is None:
            continue

        marker = datetime.fromisoformat(marker_raw.replace("Z", "+00:00"))
        if marker.tzinfo is None:
            marker = marker.replace(tzinfo=timezone.utc)

        if marker > cutoff:
            continue

        reset_job_to_pending(client, job["id"])
        recovered += 1
        logger.warning("Reset stuck job %s to pending", job["id"])

    return recovered


def process_job(
    client: Client,
    config: WorkerConfig,
    model: WhisperModel,
    job: dict,
) -> None:
    job_id = job["id"]
    meeting_id = job["meeting_id"]
    audio_path = job["audio_path"]
    local_audio: Path | None = None

    logger.info(
        "Processing job %s (meeting=%s, audio=%s)",
        job_id,
        meeting_id,
        audio_path,
    )

    try:
        local_audio = download_audio(client, config, audio_path)
        segments = transcribe_audio(local_audio, config, model)
        transcription = build_transcription_payload(segments)
        write_meeting_transcription(client, meeting_id, transcription)
        mark_job_completed(client, job_id)

        logger.info(
            "Job %s completed (%d segments written to meetings.transcription)",
            job_id,
            len(segments),
        )
    except Exception as exc:
        logger.exception("Job %s failed", job_id)
        try:
            mark_job_failed(client, job_id, str(exc))
        except Exception:
            logger.exception(
                "Failed to persist failure for job %s; resetting to pending",
                job_id,
            )
            try:
                reset_job_to_pending(client, job_id)
            except Exception:
                logger.exception("Failed to reset job %s to pending", job_id)
    finally:
        if local_audio is not None and local_audio.exists():
            os.unlink(local_audio)


def run_worker(config: WorkerConfig, *, once: bool = False) -> None:
    client = create_supabase_client(config)
    logger.info(
        "Loading Whisper model '%s' on %s (%s)",
        config.whisper_model,
        config.whisper_device,
        config.whisper_compute_type,
    )
    model = WhisperModel(
        config.whisper_model,
        device=config.whisper_device,
        compute_type=config.whisper_compute_type,
    )

    while True:
        recover_stuck_jobs(client, timeout_seconds=config.stuck_job_timeout_seconds)

        job = claim_next_job(client)
        if job is None:
            if once:
                logger.info("No pending jobs")
                return
            time.sleep(config.poll_interval_seconds)
            continue

        try:
            process_job(client, config, model, job)
        except Exception:
            logger.exception("Unexpected error handling job %s", job["id"])

        if once:
            return


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ell-ena faster-whisper transcription worker",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Process at most one pending job, then exit",
    )
    args = parser.parse_args()

    try:
        config = WorkerConfig.from_env()
    except ValueError as exc:
        logger.error("%s", exc)
        return 1

    try:
        run_worker(config, once=args.once)
    except KeyboardInterrupt:
        logger.info("Worker stopped")
        return 0
    except Exception:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
