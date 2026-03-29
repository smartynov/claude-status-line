#!/usr/bin/env bash
set -euo pipefail

# Claude Code Status Line — installer
# https://github.com/egerev/claude-status-line

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📊 Installing Claude Code Status Line..."
echo ""

# 1. Python 3.9+ (stdlib-only scripts; no pip deps)
if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found. Install Python 3.9+ (e.g. python.org, Homebrew, apt)."
    exit 1
fi
py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null) || true
py_major=$(python3 -c 'import sys; print(sys.version_info.major)' 2>/dev/null) || true
if [ "${py_major:-0}" -lt 3 ] || { [ "${py_major:-0}" -eq 3 ] && [ "${py_minor:-0}" -lt 9 ]; }; then
    echo "❌ Need Python 3.9 or newer (found ${py_major:-?}.${py_minor:-?})."
    exit 1
fi
echo "   ✓ python3 OK ($(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])'))"

# 2. Check Claude Code version
if command -v claude &>/dev/null; then
    version=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo "   Claude Code version: $version"

    # Compare versions (need 2.1.83+)
    required="2.1.83"
    if [ "$version" != "unknown" ]; then
        if printf '%s\n' "$required" "$version" | sort -V | head -1 | grep -q "$required"; then
            echo "   ✓ Version OK"
        else
            echo ""
            echo "⚠️  Claude Code $version is too old. Need $required+ for rate limits."
            echo "   Update: npm install -g @anthropic-ai/claude-code@latest"
            echo ""
            read -p "   Continue anyway? (y/N) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        fi
    fi
else
    echo "⚠️  Claude Code not found in PATH (might still work if installed elsewhere)"
fi

# 3. Create directories
mkdir -p "$CLAUDE_DIR/status_lines"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/data/sessions"

# 4. Copy scripts
cp "$SCRIPT_DIR/status_line.py" "$CLAUDE_DIR/status_lines/status_line.py"
cp "$SCRIPT_DIR/hook_prompt_submit.py" "$CLAUDE_DIR/hooks/hook_prompt_submit.py"
echo "   ✓ Scripts copied to ~/.claude/"

# 5. Patch settings.json (always overwrite statusLine, add hook if missing)
SETTINGS="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# Backup existing settings
cp "$SETTINGS" "$SETTINGS.backup.$(date +%s)"

python3 << 'PATCH_SETTINGS'
import json
import re
import shlex
from pathlib import Path

claude_dir = Path.home() / ".claude"
settings_path = claude_dir / "settings.json"
status_py = claude_dir / "status_lines" / "status_line.py"
hook_py = claude_dir / "hooks" / "hook_prompt_submit.py"

status_cmd = f"python3 {shlex.quote(str(status_py))}"
hook_cmd = f"python3 {shlex.quote(str(hook_py))}"

with open(settings_path, "r", encoding="utf-8") as f:
    raw = f.read()

# Strip comments and trailing commas (settings.json often has them)
raw = re.sub(r"//.*?\n", "\n", raw)
raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
raw = re.sub(r",\s*([}\]])", r"\1", raw)

try:
    settings = json.loads(raw)
except json.JSONDecodeError:
    print("   ⚠ Could not parse settings.json — starting fresh (backup saved)")
    settings = {}

# Always set our statusLine (overwrite any existing)
old_status = settings.get("statusLine")
settings["statusLine"] = {
    "type": "command",
    "command": status_cmd,
    "padding": 0,
}
if old_status:
    print("   ⚠ Replaced existing statusLine (backup saved)")
else:
    print("   ✓ Added statusLine")

hooks = settings.setdefault("hooks", {})
if "UserPromptSubmit" not in hooks:
    hooks["UserPromptSubmit"] = []

# Migrate older installs (uv / tilde paths) to python3 + absolute path
for block in hooks["UserPromptSubmit"]:
    for hh in block.get("hooks", []):
        c = hh.get("command", "")
        if "hook_prompt_submit.py" in c:
            hh["command"] = hook_cmd

existing = [
    h
    for h in hooks["UserPromptSubmit"]
    if any(
        "hook_prompt_submit.py" in hh.get("command", "") for hh in h.get("hooks", [])
    )
]
if not existing:
    hooks["UserPromptSubmit"].append(
        {"hooks": [{"type": "command", "command": hook_cmd}]}
    )
    print("   ✓ Added UserPromptSubmit hook")
else:
    print("   ✓ UserPromptSubmit hook OK (updated command if needed)")

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
PATCH_SETTINGS

echo ""
echo "✅ Done! Restart Claude Code to see the status line."
echo ""
echo "   What you'll see:"
echo "   [Opus 4.6 · high] | 1M [██░░░░░░░░] 6% ~192p | Cache:99% | ⏱ 25m | 5h [█░░░░░░░░░] 8% · 7d [█████████░] 91% ~9p ↻3h"
echo ""
echo "   Settings backup: $SETTINGS.backup.*"
