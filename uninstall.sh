#!/usr/bin/env bash
set -euo pipefail

# Claude Code Status Line — uninstaller

CLAUDE_DIR="$HOME/.claude"

echo "Removing Claude Code Status Line..."

# Remove scripts
rm -f "$CLAUDE_DIR/status_lines/status_line.py"
rm -f "$CLAUDE_DIR/hooks/hook_prompt_submit.py"

# Remove statusLine and hook from settings.json
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
    python3 -c "
import json

with open('$SETTINGS', 'r') as f:
    settings = json.load(f)

settings.pop('statusLine', None)

hooks = settings.get('hooks', {})
if 'UserPromptSubmit' in hooks:
    hooks['UserPromptSubmit'] = [
        h for h in hooks['UserPromptSubmit']
        if not any('hook_prompt_submit.py' in hh.get('command', '')
                   for hh in h.get('hooks', []))
    ]
    if not hooks['UserPromptSubmit']:
        del hooks['UserPromptSubmit']

with open('$SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"
    echo "   Cleaned settings.json"
fi

echo ""
echo "Done. Status line removed. Rate history kept at ~/.claude/data/rate_history.jsonl"
