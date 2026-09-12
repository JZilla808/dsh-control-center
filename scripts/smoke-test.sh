#!/bin/zsh
# =============================================================================
#  dsh-control-center — smoke test
#
#  Guards the class of bug that made the Language row blank the whole console:
#  code that needs a terminal (the picker renders with fzf and reads the
#  keyboard) being run where stdout is not a terminal. A command substitution
#  around it silently turns the UI into a pipe, the screen goes blank, and
#  `read` blocks on a prompt nobody can see.
#
#  These checks are behavioural, not unit tests: they drive the real program in
#  a real pty and look at what actually got painted.
#
#  Usage:  scripts/smoke-test.sh
#  Needs:  tmux
# =============================================================================
set -u

ROOT="${0:A:h:h}"
BIN="$ROOT/bin/dsh-control-center"
SANDBOX="$(mktemp -d)"
export DSH_CC_HOME="$SANDBOX"       # never touch the user's real preference
unset DSH_LANG

pass=0
fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; (( pass++ )); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; (( fail++ )); }

command -v tmux >/dev/null 2>&1 || { echo "tmux is required for the smoke test" >&2; exit 2; }

screen() { tmux capture-pane -pt "$1" 2>/dev/null; }
kill_all() { for s in smoke1 smoke2; do tmux kill-session -t $s 2>/dev/null; done }
trap 'kill_all; rm -rf "$SANDBOX"' EXIT

echo "dsh-control-center smoke test"
echo

# --- 1. the language picker must actually paint ---------------------------------
# This is the regression: if the picker is ever called inside $( ), the screen
# stays blank and the process hangs.
kill_all
# NOTE: no stdout redirection here. The picker only reaches for fzf when stdout
# is a terminal, so `>/dev/null` would fake the exact failure being tested.
tmux new-session -d -s smoke1 -x 100 -y 24 "DSH_CC_HOME='$SANDBOX' DSH_LANG=en '$BIN' language; echo DONE_MARKER; sleep 30"
sleep 4
scr="$(screen smoke1)"
if printf '%s' "$scr" | grep -q '简体中文' && printf '%s' "$scr" | grep -q 'English'; then
  ok "language picker paints both options"
else
  bad "language picker painted nothing (blank screen?)"
fi
if printf '%s' "$scr" | grep -q 'Language'; then
  ok "language picker shows its border label"
else
  bad "language picker border label missing"
fi

# --- 2. choosing a language must persist and return ----------------------------
tmux send-keys -t smoke1 Down; sleep 0.4
tmux send-keys -t smoke1 Enter; sleep 2
if [ "$(cat "$SANDBOX/lang" 2>/dev/null)" = "zh" ]; then
  ok "choice persisted to \$DSH_CC_HOME/lang"
else
  bad "choice was not persisted (got '$(cat "$SANDBOX/lang" 2>/dev/null)')"
fi
if screen smoke1 | grep -q 'DONE_MARKER'; then
  ok "picker returns control instead of hanging"
else
  bad "picker did not return (still blocked?)"
fi

# --- 3. the picker must not hang when there is no terminal ---------------------
# `read` on a closed stdin has to fall through to the cancelled path.
kill_all
out="$(DSH_CC_HOME="$SANDBOX" DSH_LANG=en printf '' | timeout 10 "$BIN" language 2>&1)"; rc=$?
if [ "$rc" -ne 124 ]; then
  ok "no-tty invocation exits (rc=$rc) rather than hanging"
else
  bad "no-tty invocation hung until the timeout"
fi

# --- 4. the main menu still paints, in the stored language ---------------------
kill_all
tmux new-session -d -s smoke2 -x 110 -y 32 "DSH_CC_HOME='$SANDBOX' DSH_NO_BROWSER=1 DSH_NO_SPLASH=1 '$BIN'; sleep 30"
sleep 4
scr="$(screen smoke2)"
if printf '%s' "$scr" | grep -q 'DSH' && printf '%s' "$scr" | grep -qE '启动 Web UI|Start Web UI'; then
  ok "main menu paints in the stored language"
else
  bad "main menu did not paint"
fi
if printf '%s' "$scr" | grep -q 'Language / 语言'; then
  ok "the Language row is reachable"
else
  bad "the Language row is missing from the menu"
fi

kill_all
echo
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
