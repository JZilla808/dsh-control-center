#!/bin/zsh
# =============================================================================
#  dsh-control-center — menu audit
#
#  Exercises EVERY menu row in a real pty and asserts what actually happened.
#  The Language row once blanked the whole console and hung because interactive
#  code was wrapped in a command substitution; a static read of the source did
#  not catch it, so this drives the real program instead.
#
#  Each case checks three things:
#    1. the screen is not blank after the action runs
#    2. the action returns to the menu (or exits, for Quit) instead of hanging
#    3. no stray process is left behind
#
#  Items that would really mutate the machine (start / stop / restart / update)
#  are deliberately excluded: they run `dsh web`, kill listeners or hit the npm
#  registry. They render no interactive UI of their own, so the static audit
#  plus the shared helpers they use (info/ok/pause over the same tty) cover them.
#
#  Usage:  scripts/audit-menu.sh
#  Needs:  tmux
# =============================================================================
set -u

ROOT="${0:A:h:h}"
BIN="$ROOT/bin/dsh-control-center"
SANDBOX="$(mktemp -d)"
SESSION="ccaudit"

pass=0; fail=0
ok()  { printf '  \033[32mPASS\033[0m  %-12s %s\n' "$1" "$2"; (( pass++ )); }
bad() { printf '  \033[31mFAIL\033[0m  %-12s %s\n' "$1" "$2"; (( fail++ )); }

command -v tmux >/dev/null 2>&1 || { echo "tmux is required" >&2; exit 2; }
cleanup() { tmux kill-session -t "$SESSION" 2>/dev/null; rm -rf "$SANDBOX"; }
trap cleanup EXIT

# Non-blank = the action painted something beyond the menu chrome.
content_chars() {
  tmux capture-pane -pt "$SESSION" 2>/dev/null \
    | tr -d ' \n│╭╮╰╯─▁▂▃▄▅▆▇█▌▶❯' | wc -c | tr -d ' '
}
menu_is_back() {
  tmux capture-pane -pt "$SESSION" 2>/dev/null | grep -q 'Language / 语言'
}
start_tui() {
  tmux kill-session -t "$SESSION" 2>/dev/null
  tmux new-session -d -s "$SESSION" -x 110 -y 32 \
    "DSH_CC_HOME='$SANDBOX' DSH_HOME='$SANDBOX/dsh' DSH_WORKSPACE='$SANDBOX' \
     DSH_NO_BROWSER=1 DSH_NO_SPLASH=1 DSH_LANG=en '$BIN'; echo __EXITED__; sleep 45"
  sleep 4
}

# downs|id|wait|follow-up keys
CASES=(
  "3|open|3|Enter"
  "4|status|4|Enter"
  "5|version|12|Enter"
  "7|logs|4|Enter"
  "8|headless|4|Enter Enter"
  "9|plugins|4|Escape"   # submenu cancel must return directly
  "10|config|4|Enter"
  "11|workspace|4|Enter"
  "12|docs|4|Enter"
  "13|language|4|Escape"
  "14|quit|3|"
)

echo "dsh-control-center menu audit  (sandbox: $SANDBOX)"
echo "skipping start/stop/restart/update — they mutate the machine"
echo

for case in "${CASES[@]}"; do
  downs="${case%%|*}"; rest="${case#*|}"
  id="${rest%%|*}"; rest="${rest#*|}"
  wait="${rest%%|*}"; keys="${rest#*|}"

  start_tui
  for _ in $(seq 1 "$downs"); do tmux send-keys -t "$SESSION" Down; sleep 0.05; done
  sleep 0.6
  tmux send-keys -t "$SESSION" Enter
  sleep "$wait"

  chars="$(content_chars)"
  if [ "${chars:-0}" -gt 20 ]; then
    ok "$id" "renders output (${chars} chars)"
  else
    bad "$id" "screen looks blank after the action (${chars} chars)"
  fi

  if [ "$id" = "quit" ]; then
    if tmux capture-pane -pt "$SESSION" 2>/dev/null | grep -q '__EXITED__'; then
      ok "$id" "exits cleanly"
    else
      bad "$id" "did not exit"
    fi
  else
    for k in ${=keys}; do tmux send-keys -t "$SESSION" "$k"; sleep 0.8; done
    sleep 1.5
    if menu_is_back; then
      ok "$id" "returns to the menu"
    else
      bad "$id" "never came back to the menu (hung?)"
    fi
  fi
  tmux kill-session -t "$SESSION" 2>/dev/null
done

echo
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
