#!/usr/bin/env bash
# Claude Code statusline: repo name | branch | session tokens

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
MAGENTA='\033[1;35m'
DIM='\033[2;37m'
RESET='\033[0m'

AUTOCOMPACT_LIMIT=150000

# Nerd Font codicons
ICON_FOLDER=$''
ICON_BRANCH=$''
ICON_COIN=$''
ICON_MODEL=$''
ICON_CLOCK=$''

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
transcript=$(echo "$input" | jq -r '.transcript_path // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
model="${model%% (*}"
effort=$(echo "$input" | jq -r '.effort.level // ""')
# 5-hour rolling usage-limit window (Pro/Max only; populated after first response)
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage | if . == null then empty else round end')
five_h_reset=""
if [ -n "$five_h" ]; then
  reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  # BSD date (macOS): -r reads an epoch. e.g. " 3:50PM" -> "3:50pm"
  [ -n "$reset_epoch" ] && five_h_reset=$(date -r "$reset_epoch" '+%l:%M%p' 2>/dev/null | tr 'A-Z' 'a-z' | sed 's/^ *//')
fi

[ -z "$cwd" ] && exit 0

format_tokens() {
  local n="$1"
  if [ -z "$n" ] || [ "$n" = "null" ] || [ "$n" -eq 0 ] 2>/dev/null; then
    return
  fi
  awk -v n="$n" 'BEGIN {
    if (n >= 1000000) printf "%.1fm", n/1000000
    else if (n >= 1000) printf "%.1fk", n/1000
    else printf "%d", n
  }'
}

tokens=""
pct=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  total=$(tail -r "$transcript" 2>/dev/null \
    | jq -r 'select(.message.usage) | .message.usage | (.input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0))' 2>/dev/null \
    | head -1)
  tokens=$(format_tokens "$total")
  if [ -n "$total" ] && [ "$total" != "null" ] && [ "$total" -gt 0 ] 2>/dev/null; then
    pct=$(awk -v n="$total" -v lim="$AUTOCOMPACT_LIMIT" 'BEGIN { printf "%d", (n/lim)*100 }')
  fi
fi

repo_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)

if [ -z "$repo_root" ]; then
  printf "${CYAN}%s %s${RESET}" "$ICON_FOLDER" "$(basename "$cwd")"
  [ -n "$tokens" ] && printf "   ${YELLOW}%s %s${RESET}" "$ICON_COIN" "$tokens"
  [ -n "$pct" ] && printf " ${DIM}(%s%%)${RESET}" "$pct"
  [ -n "$model" ] && printf "   ${RED}%s %s${RESET}" "$ICON_MODEL" "$model"
  [ -n "$effort" ] && printf " ${DIM}(%s)${RESET}" "$effort"
  [ -n "$five_h" ] && printf "   ${MAGENTA}%s %s%%${RESET}" "$ICON_CLOCK" "$five_h"
  [ -n "$five_h_reset" ] && printf " ${DIM}(%s)${RESET}" "$five_h_reset"
  exit 0
fi

repo_name=$(basename "$repo_root")
branch=$(git -C "$repo_root" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$repo_root" --no-optional-locks rev-parse --short HEAD 2>/dev/null \
  || echo "detached")

diff_count=$(git -C "$repo_root" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')

printf "${CYAN}%s %s${RESET}   ${GREEN}%s %s${RESET}" "$ICON_FOLDER" "$repo_name" "$ICON_BRANCH" "$branch"
[ "$diff_count" -gt 0 ] 2>/dev/null && printf " ${DIM}(● %s)${RESET}" "$diff_count"
[ -n "$tokens" ] && printf "   ${YELLOW}%s %s${RESET}" "$ICON_COIN" "$tokens"
[ -n "$pct" ] && printf " ${DIM}(%s%%)${RESET}" "$pct"
[ -n "$model" ] && printf "   ${RED}%s %s${RESET}" "$ICON_MODEL" "$model"
[ -n "$effort" ] && printf " ${DIM}(%s)${RESET}" "$effort"
[ -n "$five_h" ] && printf "   ${MAGENTA}%s %s%%${RESET}" "$ICON_CLOCK" "$five_h"
[ -n "$five_h_reset" ] && printf " ${DIM}(%s)${RESET}" "$five_h_reset"
