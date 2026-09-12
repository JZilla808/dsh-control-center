#!/bin/zsh
# =============================================================================
#  dsh-control-center · Web UI launcher
#
#  - If the Web UI is already listening, reopen its authenticated URL.
#  - Otherwise start `dsh web`, capture the token URL it prints, and open that.
#
#  Set DSH_NO_BROWSER=1 to print the URL instead of opening a browser.
#
#  The server is started in its OWN session, deliberately. `nohup … &` only
#  ignores SIGHUP; the process stays in the terminal's foreground process group,
#  so closing that window still tears the Web UI down with it. Detaching the
#  session is what actually makes the service survive the terminal.
# =============================================================================
set -u

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

PORT="${DSH_PORT:-3080}"
BASE="http://127.0.0.1:$PORT"
DSH_DIR="${DSH_HOME:-$HOME/.dsh}"
LOG="$DSH_DIR/web.log"
URL_CACHE="$DSH_DIR/web.url"
mkdir -p "$DSH_DIR"

open_url() {
  if [ "${DSH_NO_BROWSER:-0}" = "1" ]; then
    echo "OPEN $1"
  else
    /usr/bin/open "$1" 2>/dev/null || xdg-open "$1" 2>/dev/null || true
  fi
}

# Any HTTP status (401/303 included) means the server is listening; only 000 is down.
http_code() { curl -s -o /dev/null --max-time 2 -w '%{http_code}' "$BASE" 2>/dev/null; }
is_up() { [ "$(http_code)" != "000" ]; }

if ! command -v dsh >/dev/null 2>&1; then
  echo "dsh not found. Install it with: npm install -g @deepseek-ai/dsh" >&2
  exit 1
fi

if is_up; then
  if [ -s "$URL_CACHE" ]; then open_url "$(cat "$URL_CACHE")"; else open_url "$BASE"; fi
  exit 0
fi

cd "$HOME" || exit 1
rm -f "$URL_CACHE"
: > "$LOG"

# Start in a brand-new session so no controlling terminal can take it down.
# python3 gives us setsid(2) without depending on a `setsid` binary (macOS has
# none); plain `nohup &` is the fallback when python3 is unavailable.
if command -v python3 >/dev/null 2>&1; then
  nohup python3 -c '
import os, sys
if os.fork() != 0:
    os._exit(0)          # the child is never a process-group leader, so setsid succeeds
os.setsid()
os.execvp(sys.argv[1], sys.argv[1:])
' "$(command -v dsh)" web --no-open --port "$PORT" >"$LOG" 2>&1 </dev/null &
else
  nohup dsh web --no-open --port "$PORT" >"$LOG" 2>&1 </dev/null &
fi
disown 2>/dev/null || true

for _ in {1..60}; do
  URL="$(grep -o -E 'http://[^ ]*token=[A-Za-z0-9_.-]+' "$LOG" 2>/dev/null | head -1)"
  if [ -n "$URL" ]; then
    printf '%s\n' "$URL" > "$URL_CACHE"
    open_url "$URL"
    exit 0
  fi
  /bin/sleep 1
done

echo "dsh web failed to start. See $LOG" >&2
exit 1
