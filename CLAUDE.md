# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a status line for the Claude Code CLI — a bash script that reads JSON session state from stdin (sent by Claude Code's `statusLine` hook) and renders a two-line colored dashboard: model, context usage with gradient progress bar, cost, duration, git branch, rate limits, cache hit rate, and session tokens.

## Commands

```bash
# Test all display scenarios (normal, warning, danger, startup, agent, worktree, ascii, nerdfont)
./examples/test-mock.sh

# Test a single scenario
./examples/test-mock.sh normal
./examples/test-mock.sh danger
./examples/test-mock.sh ascii

# Run against a specific statusline script (defaults to ../statusline.sh)
STATUSLINE=./statusline-command.sh ./examples/test-mock.sh normal

# Install locally
./install.sh
```

## Architecture

```
Claude Code JSON (stdin)
        │
        ▼
statusline.sh ──► statusline.jq (single jq call, ~3ms)
        │               └── extracts 22 fields, one per line
        │
        ├── Git cache (/tmp/claude-statusline-git-cache, 5s TTL)
        │
        ▼
Two-line ANSI-colored output (stdout)
```

**`statusline.sh`** — The core. Bash script that:
1. Reads JSON from stdin
2. Runs a single `jq -f statusline.jq` to extract all fields at once (performance-critical)
3. Reads 22 lines from jq output via sequential `read` (one per line — avoids bash 3.2 `IFS` empty-field-collapse bugs)
4. Assembles line 1 (model, plan, progress bar, cost, time, rate limits) and line 2 (cache, tokens, git, lines changed, dir, agent/worktree)
5. Outputs via `printf '%b'` to interpret ANSI escape codes

**`statusline.jq`** — Must reside next to `statusline.sh`. A jq filter that outputs 22 lines in this exact order: `model.display_name`, `context_window.used_percentage`, `cost.total_cost_usd`, `workspace.current_dir` (basename only), `worktree.branch`, `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`, `agent.name`, `workspace.current_dir` (full path), `cost.total_lines_added`, `cost.total_lines_removed`, `cost.total_duration_ms`, `context_window.context_window_size`, `worktree.name`, `model.id`, `context_window.total_input_tokens`, `context_window.total_output_tokens`, `current_usage.cache_read_input_tokens`, `current_usage.input_tokens`, `rate_limits.five_hour.resets_at`, `rate_limits.seven_day.resets_at`, `workspace.git_worktree`, and an `"END"` sentinel. The sentinel prevents `$()` from stripping trailing empty lines from the last field.

**`statusline.ps1`** — PowerShell 5.1 port for Windows. Same two-line layout, same gradient bar, same jq dependency. Uses `[Console]::In.ReadToEnd()` for stdin and `Get-Command jq` for jq discovery.

**`statusline-command.sh`** — POSIX `/bin/sh` variant. Simpler, less feature-rich (no gradient bar, no git cache, multiple jq calls instead of one). Useful as a reference for minimal POSIX environments.

**`examples/test-mock.sh`** — Test harness with hardcoded mock JSON for scenarios: normal (42% ctx), warning (75%), danger (92%), startup (0%), agent mode, worktree mode, merged fields, ASCII mode, Nerd Font mode.

## Key design constraints

- **Bash 3.2 compatibility** (macOS default). Lookup tables for progress bar colors instead of UTF-8 substring operations. Line-by-line `read` instead of `IFS` multi-field reading (bash 3.2 silently collapses empty fields).
- **`statusline.jq` must be in the same directory** as the running script. The script uses `$SCRIPT_DIR/statusline.jq` to locate it.
- **Git cache** at `${TMPDIR:-/tmp}/claude-statusline-git-cache` with 5-second TTL to avoid blocking on every status line render.
- **Three rendering tiers**: true color 24-bit gradient (when `COLORTERM=truecolor|24bit`) → ANSI 256 color (per overall percentage) → ASCII (`CLAUDE_STATUSLINE_ASCII=1`).
- **Smart zero-value hiding**: zero durations, zero code changes, and zero rate limits are hidden entirely. `$0.00` cost stays but is dimmed.
- **Environment variables** `CLAUDE_STATUSLINE_ASCII`, `CLAUDE_STATUSLINE_NERDFONT`, `CLAUDE_STATUSLINE_POWERLINE` control the symbol set. `COLORTERM` controls true-color detection.
