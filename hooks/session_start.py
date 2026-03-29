#!/usr/bin/env python3
"""
SessionStart hook: register statusLine in ~/.claude/settings.json pointing at this plugin's status_line.py.

Plugin settings.json only supports `agent`; statusLine must be set here.

Requires Python 3.9+ (stdlib only).
"""

from __future__ import annotations

import json
import os
import re
import shlex
import shutil
import sys
from pathlib import Path

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def _normalize_settings_json(raw: str) -> str:
    raw = re.sub(r"//.*?\n", "\n", raw)
    raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return raw


def main() -> None:
    try:
        sys.stdin.read()
    except Exception:
        pass

    if not shutil.which("python3"):
        sys.exit(0)

    root = os.environ.get("CLAUDE_PLUGIN_ROOT", "").strip()
    if not root:
        sys.exit(0)

    status_py = Path(root) / "status_line.py"
    if not status_py.is_file():
        sys.exit(0)

    settings_path = Path.home() / ".claude" / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)

    if settings_path.exists():
        try:
            raw = settings_path.read_text(encoding="utf-8")
            raw = _normalize_settings_json(raw)
            settings = json.loads(raw)
        except (json.JSONDecodeError, OSError):
            settings = {}
    else:
        settings = {}

    cmd = f"python3 {shlex.quote(str(status_py.resolve()))}"
    settings["statusLine"] = {"type": "command", "command": cmd, "padding": 0}

    try:
        settings_path.write_text(
            json.dumps(settings, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
