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

# Nerd Font codicons (codepoints noted per line). The glyphs are written as raw
# UTF-8 byte escapes rather than literal characters so this file stays pure
# ASCII: it then survives copy/paste through clipboards, browsers, and Unicode
# normalizers that silently strip Private Use Area codepoints. Using \xHH (not
# \uHHHH) keeps it working on macOS's stock bash 3.2, which predates \u in $'...'.
ICON_FOLDER=$'\xEE\xAB\xB7'  # U+EAF7 codicon folder
ICON_BRANCH=$'\xEE\xA9\xA8'  # U+EA68 codicon git-branch
ICON_COIN=$'\xEE\xAA\x95'    # U+EA95 codicon credit-card
ICON_MODEL=$'\xEE\xB0\x90'   # U+EC10 codicon hubot
ICON_CLOCK=$'\xEF\x80\x97'   # U+F017 FontAwesome clock
BULLET=$'\xE2\x97\x8F'       # U+25CF dirty-file marker (not a Nerd Font glyph,
                             # but escaped too so the whole file is pure ASCII)
ARROW_UP=$'\xE2\x86\x91'     # U+2191 unpushed-commit marker

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
  if [ -n "$reset_epoch" ]; then
    # Format the epoch as local time. BSD date (macOS) takes -r <epoch>; GNU date
    # (Linux, WSL, Git Bash) takes -d @<epoch>. Try BSD, fall back to GNU.
    reset_raw=$(date -r "$reset_epoch" '+%l:%M%p' 2>/dev/null || date -d "@$reset_epoch" '+%l:%M%p' 2>/dev/null)
    five_h_reset=$(echo "$reset_raw" | tr 'A-Z' 'a-z' | sed 's/^ *//')
  fi
fi

[ -z "$cwd" ] && exit 0

# Second line: the first line of the nearest .now file at or above cwd, if any.
# Lets a workspace pin its current next step under the status line.
now_line=""
dir="$cwd"
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -f "$dir/.now" ]; then
    now_line=$(head -1 "$dir/.now")
    break
  fi
  dir=$(dirname "$dir")
done

print_now() {
  [ -n "$now_line" ] && printf "\n${GREEN}%s${RESET}" "$now_line"
}

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

# Print a file's lines newest-first: GNU `tac` where present (Linux, WSL, Git
# Bash), else BSD `tail -r` (macOS ships no tac). Keeps the token segment working
# on all three platforms, not just macOS.
reverse_lines() {
  if command -v tac >/dev/null 2>&1; then tac "$@"; else tail -r "$@"; fi
}

tokens=""
pct=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  total=$(reverse_lines "$transcript" 2>/dev/null \
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
  print_now
  exit 0
fi

repo_name=$(basename "$repo_root")
branch=$(git -C "$repo_root" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$repo_root" --no-optional-locks rev-parse --short HEAD 2>/dev/null \
  || echo "detached")

diff_count=$(git -C "$repo_root" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
# Commits on HEAD that no remote branch has: covers both a branch ahead of its
# upstream and a local branch that was never pushed.
ahead_count=$(git -C "$repo_root" --no-optional-locks rev-list --count HEAD --not --remotes 2>/dev/null)

git_parts=""
[ "$diff_count" -gt 0 ] 2>/dev/null && git_parts="$BULLET $diff_count"
if [ "$ahead_count" -gt 0 ] 2>/dev/null; then
  [ -n "$git_parts" ] && git_parts="$git_parts "
  git_parts="$git_parts$ARROW_UP $ahead_count"
fi

printf "${CYAN}%s %s${RESET}   ${GREEN}%s %s${RESET}" "$ICON_FOLDER" "$repo_name" "$ICON_BRANCH" "$branch"
[ -n "$git_parts" ] && printf " ${DIM}(%s)${RESET}" "$git_parts"
[ -n "$tokens" ] && printf "   ${YELLOW}%s %s${RESET}" "$ICON_COIN" "$tokens"
[ -n "$pct" ] && printf " ${DIM}(%s%%)${RESET}" "$pct"
[ -n "$model" ] && printf "   ${RED}%s %s${RESET}" "$ICON_MODEL" "$model"
[ -n "$effort" ] && printf " ${DIM}(%s)${RESET}" "$effort"
[ -n "$five_h" ] && printf "   ${MAGENTA}%s %s%%${RESET}" "$ICON_CLOCK" "$five_h"
[ -n "$five_h_reset" ] && printf " ${DIM}(%s)${RESET}" "$five_h_reset"
print_now
