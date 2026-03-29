#!/usr/bin/env bash
set -euo pipefail

# Claude Code Status Line — installer
# https://github.com/egerev/claude-status-line

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📊 Installing Claude Code Status Line..."

# 1. Create directories
mkdir -p "$CLAUDE_DIR/status_lines"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/data/sessions"

# 2. Copy scripts
cp "$SCRIPT_DIR/status_line.py" "$CLAUDE_DIR/status_lines/status_line.py"
cp "$SCRIPT_DIR/hook_prompt_submit.py" "$CLAUDE_DIR/hooks/hook_prompt_submit.py"
echo "   Copied scripts to ~/.claude/"

# 3. Check for uv
if ! command -v uv &>/dev/null; then
    echo ""
    echo "⚠️  'uv' not found. Install it first:"
    echo "   pip install uv"
    echo "   # or: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# 4. Patch settings.json
SETTINGS="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# Check if already configured
if grep -q "status_line.py" "$SETTINGS" 2>/dev/null; then
    echo "   settings.json already configured — skipping"
else
    # Use Python to safely merge JSON
    python3 -c "
import json, sys

settings_path = '$SETTINGS'
with open(settings_path, 'r') as f:
    settings = json.load(f)

# Add statusLine
settings['statusLine'] = {
    'type': 'command',
    'command': 'uv run ~/.claude/status_lines/status_line.py',
    'padding': 0
}

# Add hook
hooks = settings.setdefault('hooks', {})
if 'UserPromptSubmit' not in hooks:
    hooks['UserPromptSubmit'] = []

# Check if our hook already exists
existing = [h for h in hooks['UserPromptSubmit']
            if any('hook_prompt_submit.py' in hh.get('command', '')
                   for hh in h.get('hooks', []))]
if not existing:
    hooks['UserPromptSubmit'].append({
        'hooks': [{
            'type': 'command',
            'command': 'uv run ~/.claude/hooks/hook_prompt_submit.py'
        }]
    })

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"
    echo "   Updated ~/.claude/settings.json"
fi

echo ""
echo "✅ Done! Restart Claude Code to see the status line."
echo ""
echo "   What you'll see:"
echo "   [Opus 4.6 · high] | 1M [██░░░░░░░░] 6% ~192p | Cache:99% | ⏱ 25m | 5h [█░░░░░░░░░] 8% · 7d [█████████░] 91% ~9p ↻3h"
