#!/usr/bin/env bash
# ~/.claude/statusline.sh — Claude Code session status line (aesthetic edition)
#
# 兩行輸出：
#   第一行：◆ 模型 [Pro|Max] │ 漸層進度條 百分比 │ 費用 │ 時間 │ 速率限制（可含重置時間）
#   第二行：Cache／In·Out │ 倉庫(分支)* │ +增/-減 │ 目錄 │ git worktree │ Agent
#
# 環境變數：
#   CLAUDE_STATUSLINE_ASCII=1     退回純 ASCII
#   CLAUDE_STATUSLINE_NERDFONT=1  啟用 Nerd Font 圖示
#   CLAUDE_STATUSLINE_POWERLINE=1 啟用 Powerline 分隔符（預設跟隨 NERDFONT）
#   COLORTERM=truecolor|24bit     系統自動設定，啟用真彩色漸層

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# 環境偵測
# ═══════════════════════════════════════════════════════════════

USE_ASCII="${CLAUDE_STATUSLINE_ASCII:-0}"
USE_NERDFONT="${CLAUDE_STATUSLINE_NERDFONT:-0}"
USE_POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$USE_NERDFONT}"
USE_TRUECOLOR=0
if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
  USE_TRUECOLOR=1
fi

# ═══════════════════════════════════════════════════════════════
# 色彩與符號
# ═══════════════════════════════════════════════════════════════

RST='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'
GRAY='\033[90m'
DIM='\033[2m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
MAGENTA='\033[35m'

# Anthropic 品牌紫 (#7266EA)
if (( USE_TRUECOLOR )); then
  PURPLE='\033[38;2;114;102;234m'
else
  PURPLE='\033[35m'
fi

# 符號集
if [[ "$USE_ASCII" == "1" ]]; then
  S_BRAND="<>"
  S_BRANCH=">"
  S_WARN="!"
  S_PROMPT=">"
  S_TIME=""
  S_COST=""
  SEP=" | "
elif [[ "$USE_NERDFONT" == "1" ]]; then
  S_BRAND="◆"
  S_BRANCH=" "
  S_WARN=" 󰀦"
  S_PROMPT="❯"
  S_TIME="󰔟 "
  S_COST=" "
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
else
  S_BRAND="◆"
  S_BRANCH="⎇"
  S_WARN=" ⚠"
  S_PROMPT="❯"
  S_TIME=""
  S_COST=""
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 降級輸出
# ═══════════════════════════════════════════════════════════════

fallback_prompt() {
  printf '%b' "${GRAY}${1:-─}${RST}"
  exit 0
}

command -v jq &>/dev/null || fallback_prompt "─ │ jq not found"

# ═══════════════════════════════════════════════════════════════
# 百分比著色（與 statusline-command 一致）
# ═══════════════════════════════════════════════════════════════

# 高占比 = 警告（上下文、速率上限）
color_pct() {
  local n="${1%.*}"
  n=${n:-0}
  if (( n >= 76 )); then printf '%b%s%%%b' "$RED" "$n" "$RST"
  elif (( n >= 51 )); then printf '%b%s%%%b' "$YELLOW" "$n" "$RST"
  else printf '%b%s%%%b' "$GREEN" "$n" "$RST"
  fi
}

# 高占比 = 好（快取命中率）
color_pct_inv() {
  local n="${1%.*}"
  n=${n:-0}
  if (( n >= 71 )); then printf '%b%s%%%b' "$GREEN" "$n" "$RST"
  elif (( n >= 41 )); then printf '%b%s%%%b' "$YELLOW" "$n" "$RST"
  else printf '%b%s%%%b' "$RED" "$n" "$RST"
  fi
}

# ═══════════════════════════════════════════════════════════════
# 讀取 JSON（單次 jq）
# ═══════════════════════════════════════════════════════════════

input=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ_FILE="${SCRIPT_DIR}/statusline.jq"
if [[ ! -f "$JQ_FILE" ]]; then
  fallback_prompt "─ │ statusline.jq missing next to statusline.sh"
fi

parsed=$(echo "$input" | jq -r -f "$JQ_FILE" 2>/dev/null) || fallback_prompt "─ │ parse error"

{
  IFS= read -r model_name
  IFS= read -r ctx_pct
  IFS= read -r cost
  IFS= read -r dir
  IFS= read -r branch
  IFS= read -r rate5h
  IFS= read -r rate7d
  IFS= read -r agent_name
  IFS= read -r cwd_full
  IFS= read -r lines_add
  IFS= read -r lines_rm
  IFS= read -r duration_ms
  IFS= read -r ctx_size
  IFS= read -r wt_name
  IFS= read -r model_id
  IFS= read -r total_in
  IFS= read -r total_out
  IFS= read -r cache_read
  IFS= read -r cur_input
  IFS= read -r rate5h_reset
  IFS= read -r rate7d_reset
  IFS= read -r git_worktree_json
  IFS= read -r _sentinel
} <<< "$parsed"

# ═══════════════════════════════════════════════════════════════
# 模型與 Plan（與 statusline-command 一致）
# ═══════════════════════════════════════════════════════════════

model="${model_name:-─}"

plan="Pro"
case "${model_id:-}" in
  *claude-opus*|*claude-3-opus*) plan="Max" ;;
esac
plan_section=" ${GRAY}[${plan}]${RST}"

# ═══════════════════════════════════════════════════════════════
# 上下文進度條
# ═══════════════════════════════════════════════════════════════

pct_int=${ctx_pct%.*}
pct_int=${pct_int:-0}
if (( pct_int < 0 )); then pct_int=0; fi
if (( pct_int > 100 )); then pct_int=100; fi

bar_filled=$(( pct_int / 10 ))
if (( bar_filled > 10 )); then bar_filled=10; fi

# 漸層色（真彩色）：綠 → 黃 → 橘 → 紅
GRAD_R=(46 116 186 241 239 236 233 231 211 192)
GRAD_G=(204 195 186 196 161 126 101 76 66 57)
GRAD_B=(113 89 64 15 24 34 44 60 50 43)

bar=""
if [[ "$USE_ASCII" == "1" ]]; then
  # ASCII 模式
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="#"; else bar+="-"; fi
  done
elif (( USE_TRUECOLOR )); then
  # 真彩色漸層：每格獨立上色
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then
      bar+="\\033[38;2;${GRAD_R[$i]};${GRAD_G[$i]};${GRAD_B[$i]}m█"
    else
      bar+="\\033[38;2;60;60;60m░"
    fi
  done
  bar+="${RST}"
else
  # ANSI 退回：依整體百分比選色
  if (( pct_int >= 90 )); then bar_color="$RED"
  elif (( pct_int >= 70 )); then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi

  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="█"; else bar+="░"; fi
  done
  bar="${bar_color}${bar}${RST}"
fi

# 百分比文字顏色（跟進度條整體色一致）
if (( pct_int >= 90 )); then pct_color="$RED"
elif (( pct_int >= 70 )); then pct_color="$YELLOW"
else pct_color="$GREEN"; fi

# 警告符號
ctx_warn=""
if (( pct_int >= 90 )); then ctx_warn="${RED}${S_WARN}${RST}"; fi

# 上下文視窗大小（僅在 model display_name 不包含 context 資訊時才顯示）
ctx_size_int=${ctx_size:-0}
ctx_label=""
if [[ "$model" != *context* && "$model" != *Context* ]]; then
  if (( ctx_size_int >= 1000000 )); then ctx_label=" ${GRAY}1M${RST}"
  elif (( ctx_size_int >= 200000 )); then ctx_label=" ${GRAY}200k${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 費用
# ═══════════════════════════════════════════════════════════════

cost_val="${cost:-0}"
cost_fmt=$(printf '%.2f' "$cost_val" 2>/dev/null || echo "0.00")
cost_int=${cost_val%.*}
cost_int=${cost_int:-0}

if (( cost_int >= 10 )); then cost_color="$RED"
elif (( cost_int >= 5 )); then cost_color="$YELLOW"
elif [[ "$cost_fmt" == "0.00" ]]; then cost_color="$GRAY"
else cost_color="$YELLOW"; fi

# ═══════════════════════════════════════════════════════════════
# 經過時間（零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════

dur_ms=${duration_ms:-0}
dur_section=""
if (( dur_ms > 0 )); then
  dur_sec=$((dur_ms / 1000))
  dur_min=$((dur_sec / 60))
  dur_s=$((dur_sec % 60))
  # 格式化後仍為 0m0s 就不顯示（session 啟動初期 dur_ms 可能是幾百毫秒）
  if (( dur_min > 0 || dur_s > 0 )); then
    dur_section="${SEP}${GRAY}${S_TIME}${dur_min}m${dur_s}s${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 快取命中率與會話 Token（與 statusline-command 一致）
# ═══════════════════════════════════════════════════════════════

cache_read=${cache_read:-0}
cur_input=${cur_input:-0}
cache_pct=0
if (( cache_read > 0 || cur_input > 0 )); then
  total_cu=$((cache_read + cur_input))
  if (( total_cu > 0 )); then
    cache_pct=$((cache_read * 100 / total_cu))
  fi
fi

cache_section=""
if (( cache_read > 0 || cur_input > 0 )); then
  cache_section="${GRAY}Cache:${RST} $(color_pct_inv "$cache_pct")"
fi

token_section=""
if [[ -n "${total_in}" && -n "${total_out}" ]]; then
  in_k=$(echo "$total_in" | awk '{printf "%.0fk", $1/1000}')
  out_k=$(echo "$total_out" | awk '{printf "%.0fk", $1/1000}')
  token_section="${CYAN}In:${RST} ${in_k}  ${CYAN}Out:${RST} ${out_k}"
fi

# ═══════════════════════════════════════════════════════════════
# Git 分支與髒標記（帶快取，含倉庫名）
# ═══════════════════════════════════════════════════════════════

SL_TMP="${TMPDIR:-/tmp}"
if [[ -n "${TEMP:-}" ]]; then
  SL_TMP="$TEMP"
fi
GIT_CACHE="${SL_TMP}/claude-statusline-git-cache"
GIT_CACHE_MAX_AGE=5

git_cache_mtime() {
  if stat -f %m "$1" &>/dev/null; then
    stat -f %m "$1"
  elif stat -c %Y "$1" &>/dev/null; then
    stat -c %Y "$1"
  else
    echo 0
  fi
}

git_branch="${branch:-}"
dirty=""
git_repo=""

git_cache_is_stale() {
  [[ ! -f "$GIT_CACHE" ]] && return 0
  local now mt
  now=$(date +%s)
  mt=$(git_cache_mtime "$GIT_CACHE")
  local cache_age=$((now - mt))
  (( cache_age > GIT_CACHE_MAX_AGE ))
}

if [[ -n "${cwd_full:-}" && -d "${cwd_full:-}" ]]; then
  if git_cache_is_stale; then
    if git -C "$cwd_full" rev-parse --git-dir &>/dev/null; then
      cached_repo="$(basename "$(git -C "$cwd_full" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || true)"
      cached_branch="${git_branch}"
      if [[ -z "$cached_branch" ]]; then
        cached_branch=$(git -C "$cwd_full" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null) || true
        if [[ -z "$cached_branch" ]]; then
          cached_branch=$(git -C "$cwd_full" rev-parse --short HEAD 2>/dev/null) || true
        fi
      fi
      cached_dirty=""
      if ! git -C "$cwd_full" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null || \
         ! git -C "$cwd_full" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
        cached_dirty="*"
      fi
      echo "${cached_repo}|${cached_branch}|${cached_dirty}" > "$GIT_CACHE"
    else
      echo "||" > "$GIT_CACHE"
    fi
  fi

  if [[ -f "$GIT_CACHE" ]]; then
    IFS='|' read -r cached_repo cached_br cached_dt < "$GIT_CACHE"
    git_repo="${cached_repo}"
    if [[ -z "$git_branch" ]]; then git_branch="${cached_br}"; fi
    dirty="${cached_dt}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 行數增減（零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════

lines_add=${lines_add:-0}
lines_rm=${lines_rm:-0}
lines_section=""
if (( lines_add > 0 || lines_rm > 0 )); then
  lines_section="${GREEN}+${lines_add}${RST}/${RED}-${lines_rm}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# 速率限制（條件顯示，可含重置時間）
# ═══════════════════════════════════════════════════════════════

rate_section=""
rate5h_int=${rate5h%.*}; rate5h_int=${rate5h_int:-0}
rate7d_int=${rate7d%.*}; rate7d_int=${rate7d_int:-0}

rate_parts=""
if (( rate5h_int >= 0 )); then
  reset5=""
  if [[ -n "${rate5h_reset}" ]]; then
    reset5=$(date -r "${rate5h_reset}" "+%H:%M" 2>/dev/null || date -d "@${rate5h_reset}" "+%H:%M" 2>/dev/null || true)
  fi
  seg="5h: $(color_pct "${rate5h}")"
  [[ -n "$reset5" ]] && seg+=" → ${GRAY}${reset5}${RST}"
  rate_parts+="${seg}"
fi
if (( rate7d_int >= 0 )); then
  [[ -n "$rate_parts" ]] && rate_parts+="  "
  reset7=""
  if [[ -n "${rate7d_reset}" ]]; then
    reset7=$(date -r "${rate7d_reset}" "+%a %H:%M" 2>/dev/null || date -d "@${rate7d_reset}" "+%a %H:%M" 2>/dev/null || true)
  fi
  seg="7d: $(color_pct "${rate7d}")"
  [[ -n "$reset7" ]] && seg+=" → ${GRAY}${reset7}${RST}"
  rate_parts+="${seg}"
fi
if [[ -n "$rate_parts" ]]; then
  rate_section="${SEP}${rate_parts}"
fi

# ═══════════════════════════════════════════════════════════════
# 組裝第一行
# ═══════════════════════════════════════════════════════════════

line1="${PURPLE}${S_BRAND}${RST} ${CYAN}${model}${RST}${plan_section}"
line1+="${SEP}${bar} ${pct_color}${pct_int}%${RST}${ctx_warn}${ctx_label}"
line1+="${SEP}${cost_color}${S_COST}\$${cost_fmt}${RST}"
line1+="${dur_section}"
line1+="${rate_section}"

# ═══════════════════════════════════════════════════════════════
# 組裝第二行
# ═══════════════════════════════════════════════════════════════

parts=()

if [[ -n "$cache_section" ]]; then
  parts+=("${cache_section}")
fi
if [[ -n "$token_section" ]]; then
  parts+=("${token_section}")
fi

git_line=""
if [[ -n "$git_repo" && -n "$git_branch" ]]; then
  git_line="${GRAY}${git_repo} (${git_branch})${dirty}${RST}"
elif [[ -n "$git_branch" ]]; then
  git_line="${GRAY}${S_BRANCH}${git_branch}${dirty}${RST}"
fi
if [[ -n "${git_worktree_json}" ]]; then
  if [[ -n "$git_line" ]]; then
    git_line+=" ${GRAY}[${git_worktree_json}]${RST}"
  else
    git_line="${GRAY}[${git_worktree_json}]${RST}"
  fi
fi
if [[ -n "$git_line" ]]; then
  parts+=("${git_line}")
fi

if [[ -n "$lines_section" ]]; then
  parts+=("${lines_section}")
fi
parts+=("${BLUE}${dir}${RST}")

# Agent / Worktree 指示器（僅在非主 session 時顯示）
if [[ -n "${wt_name:-}" ]]; then
  parts+=("${YELLOW}⚙ worktree:${wt_name}${RST}")
elif [[ -n "${agent_name:-}" ]]; then
  parts+=("${YELLOW}⚙ ${agent_name}${RST}")
fi

line2=""
for i in "${!parts[@]}"; do
  if (( i > 0 )); then
    line2+="${SEP}"
  fi
  line2+="${parts[$i]}"
done

# ═══════════════════════════════════════════════════════════════
# 輸出
# ═══════════════════════════════════════════════════════════════

# 只輸出兩行（Claude Code 有自己的輸入提示符，不需要我們的 ❯）
printf '%b\n%b' "$line1" "$line2"
