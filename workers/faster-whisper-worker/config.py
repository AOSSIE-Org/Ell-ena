"""Configuration for the faster-whisper transcription worker."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


def _repo_root() -> Path:
    path = Path(__file__).resolve().parent
    for candidate in (path, *path.parents):
        if (candidate / "pubspec.yaml").is_file():
            return candidate
    return path.parents[1]


load_dotenv(_repo_root() / ".env")


def _require(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


@dataclass(frozen=True)
class WorkerConfig:
    supabase_url: str
    supabase_service_role_key: str
    bucket_name: str
    whisper_model: str
    whisper_device: str
    whisper_compute_type: str | None
    poll_interval_seconds: int
    stuck_job_timeout_seconds: int

    @classmethod
    def from_env(cls) -> WorkerConfig:
        device = os.getenv("WHISPER_DEVICE", "cpu").strip().lower()
        compute_type = os.getenv("WHISPER_COMPUTE_TYPE", "").strip() or None

        if compute_type is None:
            compute_type = "float16" if device == "cuda" else "int8"

        return cls(
            supabase_url=_require("SUPABASE_URL"),
            supabase_service_role_key=_require("SUPABASE_SERVICE_ROLE_KEY"),
            bucket_name=os.getenv("MEETING_RECORDINGS_BUCKET", "meeting-recordings").strip(),
            whisper_model=os.getenv("WHISPER_MODEL", "base").strip(),
            whisper_device=device,
            whisper_compute_type=compute_type,
            poll_interval_seconds=int(os.getenv("POLL_INTERVAL_SECONDS", "10")),
            stuck_job_timeout_seconds=int(
                os.getenv("STUCK_JOB_TIMEOUT_SECONDS", "1800")
            ),
        )
