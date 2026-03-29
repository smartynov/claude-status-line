#!/usr/bin/env bash
set -euo pipefail

# Claude Code Status Line — installer
# https://github.com/egerev/claude-status-line

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📊 Installing Claude Code Status Line..."
echo ""

# 1. Check for python3
if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found. Please install Python 3.11+."
    exit 1
fi

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

python3 -c "
import json, re

settings_path = '$SETTINGS'
with open(settings_path, 'r') as f:
    raw = f.read()

# Strip comments and trailing commas (settings.json often has them)
raw = re.sub(r'//.*?\n', '\n', raw)           # // line comments
raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)  # /* block comments */
raw = re.sub(r',\s*([}\]])', r'\1', raw)       # trailing commas

try:
    settings = json.loads(raw)
except json.JSONDecodeError:
    print('   ⚠ Could not parse settings.json — starting fresh (backup saved)')
    settings = {}

# Always set our statusLine (overwrite any existing)
old_status = settings.get('statusLine')
settings['statusLine'] = {
    'type': 'command',
    'command': 'python3 ~/.claude/status_lines/status_line.py',
    'padding': 0
}
if old_status:
    print('   ⚠ Replaced existing statusLine (backup saved)')
else:
    print('   ✓ Added statusLine')

# Add hook if not present
hooks = settings.setdefault('hooks', {})
if 'UserPromptSubmit' not in hooks:
    hooks['UserPromptSubmit'] = []

# Remove old uv-based hook if present, add python3-based
hooks['UserPromptSubmit'] = [
    h for h in hooks['UserPromptSubmit']
    if not any('hook_prompt_submit.py' in hh.get('command', '')
               for hh in h.get('hooks', []))
]
hooks['UserPromptSubmit'].append({
    'hooks': [{
        'type': 'command',
        'command': 'python3 ~/.claude/hooks/hook_prompt_submit.py'
    }]
})
print('   ✓ Added UserPromptSubmit hook')

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"

echo ""
echo "✅ Done! Restart Claude Code to see the status line."
echo ""
echo "   What you'll see:"
echo "   [Opus 4.6 · high] | 1M [██░░░░░░░░] 6% ~192p | Cache:99% | ⏱ 25m | 5h [█░░░░░░░░░] 8% · 7d [█████████░] 91% ~9p ↻3h"
echo ""
echo "   Settings backup: $SETTINGS.backup.*"
