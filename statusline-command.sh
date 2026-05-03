#!/bin/sh
# Claude Code status line script

input=$(cat)

# ANSI colors (POSIX-safe)
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
RED=$(printf '\033[31m')
CYAN=$(printf '\033[36m')
RESET=$(printf '\033[0m')

# Color a percentage where high = bad (ctx, rate limits)
color_pct() {
   
  n=$(echo "$1" | awk '{printf "%.0f", $1}')
  if [ "$n" -ge 76 ]; then
    printf '%s%s%%%s' "$RED" "$n" "$RESET"
  elif [ "$n" -ge 51 ]; then
    printf '%s%s%%%s' "$YELLOW" "$n" "$RESET"
  else
    printf '%s%s%%%s' "$GREEN" "$n" "$RESET"
  fi
}

# Color a percentage where high = good (cache hit rate)
color_pct_inv() {
   
  n=$(echo "$1" | awk '{printf "%.0f", $1}')
  if [ "$n" -ge 71 ]; then
    printf '%s%s%%%s' "$GREEN" "$n" "$RESET"
  elif [ "$n" -ge 41 ]; then
    printf '%s%s%%%s' "$YELLOW" "$n" "$RESET"
  else
    printf '%s%s%%%s' "$RED" "$n" "$RESET"
  fi
}

# --- Line 1: Model + Plan, Git info ---

model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
case "$model_id" in
  *claude-opus*|*claude-3-opus*) plan="Max" ;;
  *) plan="Pro" ;;
esac

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
git_info=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  repo_name=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  worktree_name=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
  if [ -n "$worktree_name" ]; then
    git_info="$repo_name ($branch) [$worktree_name]"
  else
    git_info="$repo_name ($branch)"
  fi
else
  git_info="no git"
fi

line1="${model_name} [${plan}]  ${git_info}"

# --- Line 2 ---

# Context window usage %
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_part=""
if [ -n "$ctx_used" ]; then
  ctx_part="Ctx: $(color_pct "$ctx_used")"
fi

# Cache hit rate from current_usage
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_part=""
cache_pct=$(echo "$cur_input $cache_read" | awk '{
  total = $1 + $2
  if (total > 0) printf "%.0f", $2 / total * 100
  else print "0"
}')
if [ "$cache_read" -gt 0 ] || [ "$cur_input" -gt 0 ]; then
  cache_part="Cache: $(color_pct_inv "$cache_pct")"
fi

# Session total tokens
in_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
out_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
token_part=""
if [ -n "$in_tokens" ] && [ -n "$out_tokens" ]; then
  in_k=$(echo  "$in_tokens"  | awk '{printf "%.0fk", $1/1000}')
  out_k=$(echo "$out_tokens" | awk '{printf "%.0fk", $1/1000}')
  token_part="${CYAN}In:${RESET} ${in_k}  ${CYAN}Out:${RESET} ${out_k}"
fi

# Session cost (directly from Claude Code)
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_part=""
if [ -n "$cost_usd" ]; then
  cost_fmt=$(echo "$cost_usd" | awk '{
    if ($1 < 0.01) printf "%.4f", $1
    else printf "%.2f", $1
  }')
  cost_part="${CYAN}~\$${cost_fmt}${RESET}"
fi

# 5-hour rate limit
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
five_part=""
if [ -n "$five_pct" ]; then
  if [ -n "$five_resets" ]; then
    reset_time=$(date -r "$five_resets" "+%H:%M" 2>/dev/null || date -d "@$five_resets" "+%H:%M" 2>/dev/null)
    five_part="5h: $(color_pct "$five_pct") → ${reset_time}"
  else
    five_part="5h: $(color_pct "$five_pct")"
  fi
fi

# 7-day rate limit
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
week_part=""
if [ -n "$week_pct" ]; then
  if [ -n "$week_resets" ]; then
    week_reset=$(date -r "$week_resets" "+%a %H:%M" 2>/dev/null || date -d "@$week_resets" "+%a %H:%M" 2>/dev/null)
    week_part="7d: $(color_pct "$week_pct") → ${week_reset}"
  else
    week_part="7d: $(color_pct "$week_pct")"
  fi
fi

# Assemble line 2
left=""
for part in "$ctx_part" "$cache_part" "$token_part" "$cost_part"; do
  if [ -n "$part" ]; then
    if [ -n "$left" ]; then left="${left}  "; fi
    left="${left}${part}"
  fi
done

right=""
for part in "$five_part" "$week_part"; do
  if [ -n "$part" ]; then
    if [ -n "$right" ]; then right="${right}  "; fi
    right="${right}${part}"
  fi
done

line2="$left"
if [ -n "$right" ]; then
  if [ -n "$line2" ]; then line2="${line2}  |  "; fi
  line2="${line2}${right}"
fi

printf "%s\n%s\n" "$line1" "$line2"
