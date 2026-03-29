# Claude Code Status Line

A rich, informative status bar for [Claude Code](https://claude.ai/claude-code) that shows everything you need at a glance.

```
[Opus 4.6 · high] | 1M [██░░░░░░░░] 6% ~192p | Cache:99% | ⏱ 25m | 5h [█░░░░░░░░░] 8% · 7d [█████████░] 91% ~9p ↻3h
```

## What it shows

| Segment | Example | Description |
|---------|---------|-------------|
| **Model** | `[Opus 4.6 · high]` | Active model + reasoning effort level |
| **Context** | `1M [██░░░░░░░░] 6% ~192p` | Context window size, usage bar, % used, estimated prompts remaining |
| **Cache** | `Cache:99%` | Prompt cache hit rate (green ≥80%, yellow ≥50%, red <50%) |
| **Duration** | `⏱ 25m` | How long the current session has been running |
| **5h Limit** | `5h [█░░░░░░░░░] 8%` | 5-hour sliding window rate limit usage |
| **7d Limit** | `7d [█████████░] 91% ~9p ↻3h` | 7-day rate limit with remaining prompts estimate and reset timer |

## Metrics explained

### Context window (`~192p`)
Estimates how many more prompts fit before the context window is full. Based on your average token consumption per prompt in the current session. Resets with each new session.

**Color thresholds** (based on [MRCR v2 benchmarks](https://x.com/rohanpaul_ai/status/2019545018051240059) and [context rot research](https://www.trychroma.com/research/context-rot)):
- 🟢 Green (0-20%): ~93%+ accuracy, no meaningful degradation
- 🟡 Yellow (20-40%): ~89-93% accuracy, mild degradation on complex reasoning
- 🔴 Red (40%+): Below ~89%, significant degradation, consider `/clear`

Opus 4.6 loses ~2% effectiveness per 100K tokens. These thresholds apply to both Opus 4.6 and Sonnet 4.6 (same architecture).

### Cache hit rate
Shows what percentage of input tokens came from cache vs. being processed fresh. Higher = more efficient, lower cost on API plans.

- 🟢 ≥80% — Excellent, most tokens cached
- 🟡 50-79% — Moderate
- 🔴 <50% — Low cache efficiency (normal after `/clear` or new session)

### Rate limits (`~9p`, `↻3h`)

**`~9p`** — Estimated remaining prompts before hitting the limit. Calculated from your historical usage patterns across all sessions. Gets more accurate over time.

**`↻3h`** — Time until the limit resets to zero. Both limits reset completely at the shown time:
- **5-hour limit**: Resets every ~5 hours on a fixed timer
- **7-day limit**: Resets every ~7 days on a fixed timer

`↻` always shows the time until the limit resets to zero. `~Np` only appears when yellow or red (≥50% used).

**Color thresholds:**
- 🟢 <50% — Plenty of room
- 🟡 50-80% — Getting there
- 🔴 >80% — Running low

### How prompt estimation works

The status line records rate limit percentages after each prompt in `rate_history.jsonl` under your data directory (`~/.claude/data` when installed manually, or the plugin persistent directory when installed as a plugin). It groups data by session, calculates how much each prompt consumed on average, and extrapolates remaining prompts. The estimate accounts for your mix of light prompts and heavy autonomous workflows.

## Installation

### Prerequisites
- [Claude Code](https://claude.ai/claude-code) v2.1.83+
- **Python 3.9+** on your `PATH` as `python3` (stdlib only — no pip packages)

### Install as a plugin (recommended)

In Claude Code, open the plugin manager (`/plugin`), add this repo as a marketplace source, then install **claude-status-line** from Discover.

```text
/plugin marketplace add egerev/claude-status-line
```

After install, use `/reload-plugins` if hooks do not apply immediately. A `SessionStart` hook registers `statusLine` in `~/.claude/settings.json` pointing at the plugin’s `status_line.py`.

**Do not combine** plugin install with the shell installer below unless you remove duplicate `UserPromptSubmit` hooks and a single `statusLine` — otherwise hooks or the status command may run twice or fight each other.

### Install with install.sh (manual)

```bash
git clone https://github.com/egerev/claude-status-line.git
cd claude-status-line
chmod +x install.sh && ./install.sh
```

Then restart Claude Code.

To **update** after `git pull`: run `./install.sh` again (it overwrites the copied scripts and refreshes `settings.json` commands).

### Update a plugin install

Use the plugin manager, e.g. `/plugin update claude-status-line@<your-marketplace-name>` (exact syntax is shown in `/plugin` for your added marketplace). Bump `version` in `.claude-plugin/plugin.json` when you ship changes so updates are detected.

### Uninstall

```bash
chmod +x uninstall.sh && ./uninstall.sh
```

## Repository layout (plugin)

```
.claude-plugin/plugin.json   # Plugin manifest
hooks/hooks.json             # SessionStart + UserPromptSubmit
hooks/session_start.py       # Writes statusLine into ~/.claude/settings.json
hooks/hook_prompt_submit.py  # Session / prompt_count tracking
status_line.py               # Status bar renderer (repo root)
```

## Files after manual install (`install.sh`)

```
~/.claude/
├── status_lines/
│   └── status_line.py      # Status bar renderer
├── hooks/
│   └── hook_prompt_submit.py  # Session tracking hook
├── data/
│   ├── sessions/            # Per-session data (auto-created)
│   └── rate_history.jsonl   # Rate limit history (grows over time)
└── settings.json            # Claude Code config (patched by installer)
```

## Customization

Edit `~/.claude/status_lines/status_line.py`:

### Change thresholds
```python
# Context degradation thresholds (% of context window)
CTX_YELLOW = 20   # yellow at 20%
CTX_RED = 40      # red at 40%

# Rate limit thresholds (% used)
RATE_YELLOW = 50  # yellow at 50%
RATE_RED = 80     # red at 80%
```

### Change bar width
Edit the default `width=10` argument in `progress_bar()` and `rate_bar()` in `status_line.py`.

### Add/remove segments
Each segment is added via `parts.append(...)` in the `generate()` function. Comment out or rearrange as needed.

## How it works

1. **No context cost** — Scripts run as external processes, not inside Claude's context window
2. **Minimal latency** — Hook adds ~50ms per prompt (Python startup + JSON write)
3. **No network calls** — Everything is local file I/O
4. **Safe** — All errors are silently caught, never breaks Claude Code

### Local plugin development

```bash
claude --plugin-dir /path/to/claude-status-line
```

Then `/reload-plugins` after editing hook or manifest files.

## Requirements

- Claude Code v2.1.83+ (for `statusLine` and `rate_limits` support in stdin JSON)
- Claude Max subscription (for rate limit data; API users see cost instead)
- Works on macOS, Linux, Windows (WSL)

## License

MIT
