#!/usr/bin/env python3
"""
Hook for UserPromptSubmit — tracks session data for the status line.

Fires on every user prompt. Records:
  1. Session file (.claude/data/sessions/{session_id}.json)
     - created_at: session start time (for duration display)
     - prompt_count: number of prompts (for context usage estimation)

Requires Python 3.9+ (stdlib only).
"""

import json
import sys
from datetime import datetime
from pathlib import Path

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SESSIONS_DIR = Path(".claude/data/sessions")


def update_session(session_id: str) -> None:
    """Create or update session file with created_at and prompt_count."""
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    session_file = SESSIONS_DIR / f"{session_id}.json"

    if session_file.exists():
        try:
            data = json.loads(session_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, ValueError):
            data = {}
    else:
        data = {}

    if "created_at" not in data:
        data["created_at"] = datetime.now().astimezone().isoformat()

    data["session_id"] = session_id
    data["prompt_count"] = data.get("prompt_count", 0) + 1

    try:
        session_file.write_text(
            json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
        )
    except Exception:
        pass


def main() -> None:
    try:
        input_data = json.loads(sys.stdin.read())
        session_id = input_data.get("session_id", "unknown")
        update_session(session_id)
        sys.exit(0)
    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
