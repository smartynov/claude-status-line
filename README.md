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

**Color thresholds** (based on LLM degradation research):
- 🟢 Green (0-10%): No quality degradation
- 🟡 Yellow (10-20%): Degradation begins for complex reasoning tasks
- 🔴 Red (20%+): Significant degradation, consider `/clear`

### Cache hit rate
Shows what percentage of input tokens came from cache vs. being processed fresh. Higher = more efficient, lower cost on API plans.

- 🟢 ≥80% — Excellent, most tokens cached
- 🟡 50-79% — Moderate
- 🔴 <50% — Low cache efficiency (normal after `/clear` or new session)

### Rate limits (`~9p`, `↻3h`)

**`~9p`** — Estimated remaining prompts before hitting the limit. Calculated from your historical usage patterns across all sessions. Gets more accurate over time.

**`↻3h`** — Time until the limit resets or eases:
- **5-hour limit**: Sliding window — old usage continuously falls off. `↻` shows when the oldest chunk drops.
- **7-day limit**: Fixed reset — resets completely at the shown time.

Both `~Np` and `↻` only appear when the limit is yellow or red (≥50% used).

**Color thresholds:**
- 🟢 <50% — Plenty of room
- 🟡 50-80% — Getting there
- 🔴 >80% — Running low

### How prompt estimation works

The status line records rate limit percentages after each prompt in `~/.claude/data/rate_history.jsonl`. It groups data by session, calculates how much each prompt consumed on average, and extrapolates remaining prompts. The estimate accounts for your mix of light prompts and heavy autonomous workflows.

## Installation

### Prerequisites
- [Claude Code](https://claude.ai/claude-code) v2.1.83+
- Python 3.11+
- [uv](https://github.com/astral-sh/uv) (`pip install uv`)

### Install

```bash
git clone https://github.com/egerev/claude-status-line.git
cd claude-status-line
chmod +x install.sh && ./install.sh
```

Then restart Claude Code.

### Uninstall

```bash
chmod +x uninstall.sh && ./uninstall.sh
```

## Files

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
CTX_YELLOW = 10   # yellow at 10%
CTX_RED = 20      # red at 20%

# Rate limit thresholds (% used)
RATE_YELLOW = 50  # yellow at 50%
RATE_RED = 80     # red at 80%
```

### Change bar width
```python
BAR_WIDTH = 10  # number of blocks in progress bars
```

### Add/remove segments
Each segment is added via `parts.append(...)` in the `generate()` function. Comment out or rearrange as needed.

## How it works

1. **No context cost** — Scripts run as external processes, not inside Claude's context window
2. **Minimal latency** — Hook adds ~50ms per prompt (Python startup + JSON write)
3. **No network calls** — Everything is local file I/O
4. **Safe** — All errors are silently caught, never breaks Claude Code

## Requirements

- Claude Code v2.1.83+ (for `statusLine` and `rate_limits` support in stdin JSON)
- Claude Max subscription (for rate limit data; API users see cost instead)
- Works on macOS, Linux, Windows (WSL)

## License

MIT
