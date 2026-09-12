# =============================================================================
#  dsh-control-center · console
#
#  A terminal control center for DeepSeek Harness (`dsh`): start / stop /
#  restart the Web UI, run headless tasks, manage plugins, read logs, update the
#  CLI — without memorising any commands.
#
#  This is a COMPANION tool, not a Cordis plugin. Its whole job is to start and
#  stop the `dsh` process, and a Cordis plugin only exists while dsh runs, so it
#  could not be one even in principle.
#
#  All user-facing copy comes from the catalogs in ../locales via ${MSG[key]}.
#  Direct parameter expansion is deliberate: the preview pane re-renders on
#  every cursor move, and `$(t key)` would fork a subshell per string.
# =============================================================================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DSH_DIR="${DSH_HOME:-$HOME/.dsh}"
LOG="$DSH_DIR/web.log"
URL_CACHE="$DSH_DIR/web.url"
VER_CACHE="${DSH_CC_HOME:-$HOME/.dsh-control-center}/.version-cache"
PORT="${DSH_PORT:-3080}"
BASE="http://127.0.0.1:$PORT"
LAUNCH_WEB="${DSH_LAUNCH_WEB:-}"
PROFILE="${DSH_PROFILE:-web}"
WORKSPACE="${DSH_WORKSPACE:-$HOME}"
PREVIEW_PCT=46

# =============================================================================
#  DESIGN SYSTEM — "Deep Sea"
#
#  • TRUE (truecolor hex) — fzf's own chrome, so the deep-ocean surface paints
#    itself regardless of the terminal profile.
#  • A_*  (xterm-256)     — text drawn inside items, the banner and the action
#    screens, where only indexed colour is reliably understood. Each value is
#    the nearest 256-cube neighbour of its hex counterpart.
# =============================================================================
if [ -t 1 ] && [ "${NO_COLOR:-0}" != "1" ]; then
  C_R=$'\e[0m'; C_B=$'\e[1m'; C_D=$'\e[2m'
  A_TEXT=$'\e[38;5;153m'
  A_MUT=$'\e[38;5;67m'
  A_FNT=$'\e[38;5;24m'
  A_ACC=$'\e[38;5;75m'
  A_GLOW=$'\e[38;5;45m'
  A_OK=$'\e[38;5;79m'
  A_WARN=$'\e[38;5;179m'
  A_ERR=$'\e[38;5;204m'
  A_VIO=$'\e[38;5;141m'
else
  C_R=""; C_B=""; C_D=""
  A_TEXT=""; A_MUT=""; A_FNT=""; A_ACC=""; A_GLOW=""; A_OK=""; A_WARN=""; A_ERR=""; A_VIO=""
fi

FZF_COLORS='bg:#04101c,list-bg:#04101c,preview-bg:#061829,fg:#cfe3f7,fg+:#ffffff,bg+:#0d3050,hl:#4ea3ff,hl+:#57d7ff,info:#4a6d8a,prompt:#57d7ff,pointer:#57d7ff,marker:#3ddc97,spinner:#57d7ff,header:#7fa8c9,footer:#4a6d8a,separator:#12314a,scrollbar:#1d4a6b,border:#17405f,label:#57d7ff,preview-border:#17405f,preview-label:#4ea3ff,query:#eaf4ff,disabled:#33556e,gutter:#04101c'

GRADIENT_RAMP=($'\e[38;5;25m' $'\e[38;5;26m' $'\e[38;5;32m' $'\e[38;5;38m' $'\e[38;5;45m' $'\e[38;5;51m')

# --- output helpers ----------------------------------------------------------
say()  { printf '%b\n' "$*"; }
ok()   { printf '  %s✔%s  %s\n' "$A_OK" "$C_R" "$*"; }
warn() { printf '  %s▲%s  %s\n' "$A_WARN" "$C_R" "$*"; }
err()  { printf '  %s✘%s  %s\n' "$A_ERR" "$C_R" "$*"; }
info() { printf '  %s◆%s  %s\n' "$A_GLOW" "$C_R" "$*"; }
dim()  { printf '%s%s%s\n' "$C_D" "$*" "$C_R"; }
rule() { printf '  %s%s%s\n' "$A_FNT" "$(printf '─%.0s' {1..54})" "$C_R"; }
pause(){ printf '\n  %s%s%s' "$C_D" "${MSG[misc.press_enter]}" "$C_R"; read -r _ || true; }

# A labelled row for action screens (cold path, so the subshell is fine).
row() { printf '  %s%s%s %s\n' "$A_MUT" "$(cc_pad "${MSG[$1]}" 8)" "$C_R" "$2"; }

# --- branding helpers --------------------------------------------------------
gradient_text() {
  local str="$1" i=0 ch out="" n=${#GRADIENT_RAMP}
  for ch in ${(s::)str}; do
    out+="${GRADIENT_RAMP[$(( i % n + 1 ))]}${ch}"
    (( i++ ))
  done
  printf '%s%s' "$out" "$C_R"
}

# --- terminal geometry -------------------------------------------------------
# Banner/preview text is built inside $(...) where stdout is a pipe; `tput cols`
# then falls back to 80, and it ioctls stdout rather than stdin. `stty size`
# reads fd 0, so redirect that from /dev/tty.
term_cols() {
  local c sz
  # The group redirect matters: when there is no controlling terminal the
  # *shell* reports the failed open, so `cmd </dev/tty 2>/dev/null` still leaks
  # "device not configured" onto stderr.
  sz=$( { stty size < /dev/tty } 2>/dev/null )
  c=${sz##* }
  case "$c" in (<->) ;; (*) c=${COLUMNS:-110} ;; esac
  case "$c" in (<->) ;; (*) c=110 ;; esac
  printf '%s' "$c"
}

LIST_W=0
list_width() {
  if [ "$LIST_W" -eq 0 ]; then
    local cols inner prev
    cols=$(term_cols)
    inner=$(( cols - 4 ))
    prev=$(( inner * PREVIEW_PCT / 100 ))
    LIST_W=$(( inner - prev - 1 ))
    [ "$LIST_W" -lt 32 ] && LIST_W=32
  fi
  printf '%s' "$LIST_W"
}

PREVIEW_W=0
preview_width() {
  if [ "$PREVIEW_W" -eq 0 ]; then
    PREVIEW_W=$(( $(term_cols) - 4 - $(list_width) - 1 ))
    [ "$PREVIEW_W" -lt 20 ] && PREVIEW_W=20
  fi
  printf '%s' "$PREVIEW_W"
}

# Sonar/depth wave, clipped to the width actually available.
wave_line() {
  local width="${1:-$(list_width)}"
  local pattern="▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂"
  local out=""
  while [ "${#out}" -lt "$width" ]; do out+="$pattern"; done
  gradient_text "${out[1,$width]}"
}

screen_header() {  # $1 glyph, $2 title
  clear
  printf '\n  %s%s%s   %s%s%s\n' "$A_ACC" "$C_B" "$1" "$C_B" "$2" "$C_R"
  rule
  printf '\n'
}

# --- state helpers -----------------------------------------------------------
server_pids() { lsof -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null }
server_pid()  { server_pids | head -1 }
is_running()  { [ -n "$(server_pid)" ] }

# `dsh --version` boots node (~200ms) and the preview re-renders on every cursor
# move, so memoise it for five minutes instead of paying that cost live.
dsh_version() {
  local now mt age v
  if [ -s "$VER_CACHE" ]; then
    mt=$(stat -f %m "$VER_CACHE" 2>/dev/null || stat -c %Y "$VER_CACHE" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( now - mt ))
    if [ "$age" -ge 0 ] && [ "$age" -lt 300 ]; then cat "$VER_CACHE"; return; fi
  fi
  if command -v dsh >/dev/null 2>&1; then v="$(dsh --version 2>/dev/null)"; else v="n/a"; fi
  mkdir -p "${VER_CACHE:h}" 2>/dev/null
  printf '%s' "$v" > "$VER_CACHE" 2>/dev/null
  printf '%s' "$v"
}

server_uptime() {
  local p; p="$(server_pid)"
  [ -z "$p" ] && { printf '—'; return; }
  local e; e="$(ps -o etime= -p "$p" 2>/dev/null | tr -d ' ')"
  printf '%s' "${e:-—}"
}

auth_url() { if [ -s "$URL_CACHE" ]; then cat "$URL_CACHE"; else echo "$BASE"; fi }
http_code() { curl -s -o /dev/null --max-time 2 -w '%{http_code}' "$BASE" 2>/dev/null; }

# Where the dsh Web UI launcher lives. We ship our own copy so the console does
# not depend on a hand-installed script; DSH_LAUNCH_WEB overrides it.
resolve_launcher() {
  if [ -n "$LAUNCH_WEB" ] && [ -x "$LAUNCH_WEB" ]; then return 0; fi
  local candidate
  for candidate in \
      "$CC_HOME/lib/launch-web.sh" \
      "$HOME/Library/Application Support/dsh-launcher/launch-web.sh"; do
    if [ -x "$candidate" ]; then LAUNCH_WEB="$candidate"; return 0; fi
  done
  return 1
}

open_it() {
  local u; u="$(auth_url)"
  if [ "${DSH_NO_BROWSER:-0}" = "1" ]; then
    say "OPEN $u"
  else
    open "$u" 2>/dev/null || xdg-open "$u" 2>/dev/null || true
    ok "$(printf "${MSG[msg.opened]}" "$u")"
  fi
}

# --- language ----------------------------------------------------------------
# First-run / on-demand picker. Only reached when neither an explicit override, a
# stored preference, nor the environment could decide.
#
# The result lands in $CC_PICKED_LANG and this must NEVER be called as
# `x="$(cc_pick_language)"`. A command substitution makes stdout a pipe, which
# breaks both halves of the picker at once: the `[ -t 1 ]` guard falls through
# so fzf is never used, and the plain-prompt fallback writes its text into the
# capture instead of the screen while `read` blocks on input the user cannot
# see. The symptom is a blank console that never comes back.
CC_PICKED_LANG=""
cc_pick_language() {
  CC_PICKED_LANG=""
  local choice=""
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    choice="$(printf '%s\n' \
        'en|English' \
        'zh|简体中文' \
      | fzf --ansi --delimiter='|' --with-nth=2 --nth=2 \
            --height=40% --layout=reverse --border=rounded \
            --border-label=" ${MSG[lang.which]} " --border-label-pos=3 \
            --padding=1 --prompt='  ▸ ' --pointer='▶' \
            --header="  ${MSG[lang.help]}" --header-first \
            --info=inline-right --color="$FZF_COLORS")" || true
    choice="${choice%%|*}"
  else
    printf '\n  %s\n' "${MSG[lang.which]}"
    printf '  1) English\n  2) 简体中文\n\n  > '
    local n; read -r n || true
    case "$n" in (2|zh) choice=zh ;; (1|en) choice=en ;; esac
  fi
  case " ${SUPPORTED_LANGS[*]} " in
    (*" $choice "*) CC_PICKED_LANG="$choice"; return 0 ;;
    (*)             return 1 ;;
  esac
}

do_language() {
  if ! cc_pick_language; then
    warn "${MSG[msg.cancelled]}"
    return 0
  fi
  cc_store_lang "$CC_PICKED_LANG"
  cc_load_messages "$CC_PICKED_LANG"
  ok "${MSG[lang.saved]}"
}

# --- banner ------------------------------------------------------------------
header_text() {
  local avail v up dot state pid
  avail=$(( $(list_width) - 6 ))
  v="$(dsh_version)"
  if is_running; then
    pid="$(server_pid)"; up="$(server_uptime)"
    dot="${A_OK}●${C_R}"; state="${A_OK}${C_B}${MSG[state.running]}${C_R}"
  else
    pid="—"; up="—"
    dot="${A_WARN}○${C_R}"; state="${A_WARN}${C_B}${MSG[state.stopped]}${C_R}"
  fi

  printf '\n  %s\n\n' "$(wave_line "$avail")"
  printf '  %s  %s\n' "${A_GLOW}◈${C_R}" "$(gradient_text 'D S H   C O N T R O L   C E N T E R')"
  printf '      %s\n\n' "${A_MUT}${MSG[app.tagline]}${C_R}"
  printf '  %s %s   %s%s%s %s   %s127.0.0.1:%s%s\n' \
    "$dot" "$state" "$A_MUT" "${MSG[banner.pid]}" "$C_R" "$A_TEXT$pid$C_R" "$A_GLOW" "$PORT" "$C_R"
  printf '  %s%s%s %s   %s%s%s %s\n' \
    "$A_MUT" "dsh" "$C_R" "$A_TEXT$v$C_R" "$A_MUT" "${MSG[banner.uptime]}" "$C_R" "$A_TEXT$up$C_R"
}

# --- intro -------------------------------------------------------------------
splash() {
  [ "${DSH_NO_SPLASH:-0}" = "1" ] && return 0
  [ -t 1 ] || return 0
  local bar="" i
  printf '\e[2J\e[H\n\n\n'
  printf '        %s\n\n' "$(wave_line 48)"
  printf '        %s  %s\n\n' "${A_GLOW}◈${C_R}" "$(gradient_text 'D S H   C O N T R O L   C E N T E R')"
  printf '            %s\n\n' "${A_MUT}${MSG[app.tagline]}${C_R}"
  for i in {1..18}; do
    bar+="█"
    printf '\r            %s%s%s%s%*s  %s%s%s' \
      "$A_GLOW" "$bar" "$C_R" "$A_FNT" $(( 18 - i )) "" "$A_MUT" "${MSG[splash.diving]}" "$C_R"
    sleep 0.018
  done
  printf '\r            %s%s%s  %s%s%s\e[K\n' "$A_OK" "$bar" "$C_R" "$A_OK" "${MSG[splash.ready]}" "$C_R"
  sleep 0.12
  clear
}

# =============================================================================
#  ACTIONS
# =============================================================================
do_start() {
  if is_running; then ok "$(printf "${MSG[msg.already_running]}" "$(server_pid)")"; open_it; return 0; fi
  info "${MSG[msg.starting]}"
  if ! resolve_launcher; then err "${MSG[msg.start_failed]}"; return 1; fi
  DSH_NO_BROWSER=1 DSH_PORT="$PORT" zsh "$LAUNCH_WEB"
  if is_running; then
    ok "$(printf "${MSG[msg.started]}" "$(server_pid)")"; open_it
  else
    err "${MSG[msg.start_failed]}"; return 1
  fi
}

do_stop() {
  local pids; pids=($(server_pids))
  if [ "${#pids[@]}" -eq 0 ]; then warn "${MSG[msg.not_running]}"; return 0; fi
  info "$(printf "${MSG[msg.stopping]}" "${pids[*]}")"
  local p
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
  sleep 1.5
  local left; left=($(server_pids))
  if [ "${#left[@]}" -eq 0 ]; then
    ok "${MSG[msg.stopped]}"
  else
    warn "${MSG[msg.still_running]}"
    for p in "${left[@]}"; do kill -9 "$p" 2>/dev/null; done
    sleep 0.5
    if is_running; then err "${MSG[msg.stop_failed]}"; return 1; else ok "${MSG[msg.stopped_forced]}"; fi
  fi
}

do_restart() { do_stop; sleep 0.5; do_start }

do_open() {
  if ! is_running; then warn "${MSG[msg.start_first]}"; do_start; return $?; fi
  open_it
}

do_status() {
  screen_header "◉" "${MSG[screen.status]}"
  if is_running; then
    printf '  %s %s%s%s   %s%s %s · %s%s\n\n' \
      "$A_OK" "$C_B" "${MSG[state.running]}" "$C_R" "$C_D" \
      "$(printf "${MSG[lbl.pid]}")" "$(server_pid)" "$(server_uptime)" "$C_R"
  else
    printf '  %s %s%s%s   %s%s%s\n\n' \
      "$A_WARN" "$C_B" "${MSG[state.stopped]}" "$C_R" "$C_D" \
      "$(printf "${MSG[lbl.port_free]}" "$PORT")" "$C_R"
  fi
  row lbl.version "$(dsh_version)"
  row lbl.node    "$(node -v 2>/dev/null || echo '?')"
  row lbl.url     "$(auth_url)"
  local hc; hc="$(http_code)"
  if [ "$hc" = "000" ]; then
    row lbl.health "${A_ERR}${MSG[st.no_response]}${C_R}"
  else
    row lbl.health "${A_OK}${MSG[st.responding]}${C_R} ${A_MUT}$(printf "${MSG[st.http_note]}" "$hc")${C_R}"
  fi
  row lbl.log    "$(printf "${MSG[st.log_lines]}" "$LOG" "$(wc -l <"$LOG" 2>/dev/null | tr -d ' ')")"
  row lbl.config "${DSH_DIR}$(printf "${MSG[st.profile_suffix]}" "$PROFILE")"
}

do_version() {
  screen_header "◈" "${MSG[screen.version]}"
  row lbl.local "$(dsh_version)"
  printf '\n  %s%s%s\n' "$A_MUT" "${MSG[lbl.channels]}" "$C_R"
  if command -v npm >/dev/null 2>&1; then
    npm view @deepseek-ai/dsh dist-tags 2>&1 | sed 's/^/      /'
  else
    warn "npm"
  fi
  printf '\n  %s%s%s\n' "$C_D" "${MSG[ver.hint]}" "$C_R"
}

do_update() {
  screen_header "▼" "${MSG[screen.update]}"
  local before after out ec
  before="$(dsh_version)"
  info "$(printf "${MSG[upd.current]}" "$before")"
  info "${MSG[upd.running]}"
  out="$(npm install -g \
    --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
    @deepseek-ai/dsh 2>&1)"
  ec=$?
  printf '%s\n' "$out" | tail -n 20
  rm -f "$VER_CACHE"
  after="$(dsh_version)"
  if [ "$ec" -eq 0 ]; then
    ok "$(printf "${MSG[upd.done]}" "$before" "$after")"
  else
    err "$(printf "${MSG[upd.failed]}" "$ec")"; return 1
  fi
}

do_logs() {
  screen_header "≡" "${MSG[screen.logs]}"
  if [ ! -s "$LOG" ]; then warn "$(printf "${MSG[logs.empty]}" "$LOG")"; return 0; fi
  printf '  %s%s%s  %s%s%s\n\n' "$A_MUT" "${MSG[logs.recent]}" "$C_R" "$C_D" "$LOG" "$C_R"
  tail -n 80 "$LOG"
  printf '\n  %s%s%s\n' "$C_D" "$(printf "${MSG[logs.follow]}" "$LOG")" "$C_R"
}

do_headless() {
  local task="${1:-}"
  screen_header "▷" "${MSG[screen.headless]}"
  if [ -z "$task" ]; then printf '  %s' "${MSG[hl.prompt]}"; read -r task; fi
  if [ -z "$task" ]; then warn "${MSG[msg.cancelled]}"; return 0; fi
  info "dsh --profile headless \"$task\""
  dim "${MSG[hl.hint]}"
  say ""
  dsh --profile headless "$task"
}

do_plugins() {
  local sub="${1:-}" pkg="${2:-}"
  case "$sub" in
    list)
      local out
      out="$(dsh plugin --profile "$PROFILE" list 2>&1)"
      if [ -n "$out" ]; then
        printf '%s\n' "$out"
      else
        printf '  %s%s%s\n\n' "$C_D" "${MSG[pl.none]}" "$C_R"
        dim "  $(printf "${MSG[pl.dir]}" "$DSH_DIR/profiles/$PROFILE")"
      fi
      ;;
    add)    [ -z "$pkg" ] && { printf '  %s' "${MSG[pl.pkg_prompt]}"; read -r pkg; }
            [ -z "$pkg" ] && { warn "${MSG[msg.cancelled]}"; return 0; }
            dsh plugin --profile "$PROFILE" add "$pkg" ;;
    remove) [ -z "$pkg" ] && { printf '  %s' "${MSG[pl.pkg_prompt]}"; read -r pkg; }
            [ -z "$pkg" ] && { warn "${MSG[msg.cancelled]}"; return 0; }
            dsh plugin --profile "$PROFILE" remove "$pkg" ;;
    update) dsh plugin --profile "$PROFILE" update ;;
    *)      plugins_menu ;;
  esac
}

do_config()    { open "$DSH_DIR"  2>/dev/null || xdg-open "$DSH_DIR"  2>/dev/null; ok "$(printf "${MSG[misc.finder_opened]}" "$DSH_DIR")"; }
do_workspace() { open "$WORKSPACE" 2>/dev/null || xdg-open "$WORKSPACE" 2>/dev/null; ok "$(printf "${MSG[misc.finder_opened]}" "$WORKSPACE")"; }

do_docs() {
  screen_header "?" "${MSG[screen.docs]}"
  printf '  %s%s%s  https://deepseek.com/harness/en/\n' "$A_MUT" "${MSG[docs.site]}" "$C_R"
  printf '  %s%s%s  https://github.com/deepseek-ai/deepseek-harness\n' "$A_MUT" "${MSG[docs.repo]}" "$C_R"
  printf '  %s%s%s  https://deepseek-harness.github.io/deepseek-harness/\n' "$A_MUT" "${MSG[docs.docs]}" "$C_R"
  printf '\n  %s%s%s\n\n' "$C_B" "${MSG[docs.covered]}" "$C_R"
  printf '  %sdsh web%s\n' "$A_TEXT" "$C_R"
  printf '  %sdsh web --no-open%s\n' "$A_TEXT" "$C_R"
  printf '  %sdsh web --port 8080%s\n' "$A_TEXT" "$C_R"
  printf '  %sdsh --profile headless "<task>"%s\n' "$A_TEXT" "$C_R"
  printf '  %sdsh plugin --profile web <pnpm args>%s\n' "$A_TEXT" "$C_R"
  printf '  %sdsh --version%s\n' "$A_TEXT" "$C_R"
  printf '  %slsof -ti tcp:%s -sTCP:LISTEN | xargs kill%s\n' "$A_TEXT" "$PORT" "$C_R"
  printf '  %stail -f ~/.dsh/web.log%s\n' "$A_TEXT" "$C_R"
  say ""
  if [ "${DSH_NO_BROWSER:-0}" = "1" ]; then
    dim "${MSG[msg.no_browser]}"
  else
    open "https://deepseek.com/harness/en/" 2>/dev/null || true
    ok "${MSG[docs.opened]}"
  fi
}

do_quit() { return 0 }

# --- plugins submenu ---------------------------------------------------------
plugins_menu() {
  if [ "${DSH_NO_FZF:-0}" = "1" ] || ! command -v fzf >/dev/null 2>&1; then
    warn "${MSG[pl.unsupported]}"
    return 0
  fi
  local items=(
    "list|${A_ACC}${C_B}≡${C_R}   ${A_TEXT}${MSG[pl.list]}${C_R}"
    "add|${A_ACC}${C_B}＋${C_R}   ${A_TEXT}${MSG[pl.add]}${C_R}"
    "remove|${A_ERR}${C_B}－${C_R}   ${A_TEXT}${MSG[pl.remove]}${C_R}"
    "update|${A_GLOW}${C_B}↓${C_R}   ${A_TEXT}${MSG[pl.update]}${C_R}"
    "back|${A_MUT}${C_B}←${C_R}   ${A_MUT}${MSG[pl.back]}${C_R}"
  )
  local sel id
  sel="$(printf '%s\n' "${items[@]}" | fzf \
      --ansi --delimiter='|' --with-nth=2 --nth=2 \
      --height=60% --layout=reverse --border=rounded \
      --border-label=" ◈  ${MSG[screen.plugins]} · $PROFILE " --border-label-pos=3 \
      --padding=1 --prompt='  ▸ ' --pointer='▶' --marker='✓' \
      --header="  ${A_MUT}$(printf "${MSG[pl.which]}" "$PROFILE")${C_R}" --header-first \
      --info=inline-right --color="$FZF_COLORS")" || return 0
  [ -z "$sel" ] && return 0
  id="${sel%%|*}"
  [ "$id" = back ] && return 0
  screen_header "▣" "${MSG[screen.plugins]} · $id"
  info "dsh plugin --profile $PROFILE $id"
  say ""
  do_plugins "$id"
  pause
}

# --- preview pane ------------------------------------------------------------
action_preview() {
  local id="$1" title="" desc="" command=""
  case "$id" in
    start)     title="${MSG[pv.start.title]}";     desc="$(printf "${MSG[pv.start.desc]}")";          command="${MSG[pv.start.cmd]}";;
    stop)      title="${MSG[pv.stop.title]}";      desc="$(printf "${MSG[pv.stop.desc]}" "$PORT")";  command="$(printf "${MSG[pv.stop.cmd]}" "$PORT")";;
    restart)   title="${MSG[pv.restart.title]}";   desc="${MSG[pv.restart.desc]}";                   command="${MSG[pv.restart.cmd]}";;
    open)      title="${MSG[pv.open.title]}";      desc="${MSG[pv.open.desc]}";                      command="${MSG[pv.open.cmd]}";;
    status)    title="${MSG[pv.status.title]}";    desc="${MSG[pv.status.desc]}";                    command="${MSG[pv.status.cmd]}";;
    version)   title="${MSG[pv.version.title]}";   desc="${MSG[pv.version.desc]}";                   command="${MSG[pv.version.cmd]}";;
    update)    title="${MSG[pv.update.title]}";    desc="${MSG[pv.update.desc]}";                    command="${MSG[pv.update.cmd]}";;
    logs)      title="${MSG[pv.logs.title]}";      desc="${MSG[pv.logs.desc]}";                      command="${MSG[pv.logs.cmd]}";;
    headless)  title="${MSG[pv.headless.title]}";  desc="${MSG[pv.headless.desc]}";                  command="${MSG[pv.headless.cmd]}";;
    plugins)   title="${MSG[pv.plugins.title]}";   desc="$(printf "${MSG[pv.plugins.desc]}")";       command="$(printf "${MSG[pv.plugins.cmd]}" "$PROFILE")";;
    config)    title="${MSG[pv.config.title]}";    desc="${MSG[pv.config.desc]}";                    command="${MSG[pv.config.cmd]}";;
    workspace) title="${MSG[pv.workspace.title]}"; desc="${MSG[pv.workspace.desc]}";                 command="$(printf "${MSG[pv.workspace.cmd]}" "$WORKSPACE")";;
    docs)      title="${MSG[pv.docs.title]}";      desc="${MSG[pv.docs.desc]}";                      command="${MSG[pv.docs.cmd]}";;
    language)  title="${MSG[pv.language.title]}";  desc="${MSG[pv.language.desc]}";                  command="${MSG[pv.language.cmd]}";;
    quit)      title="${MSG[pv.quit.title]}";      desc="${MSG[pv.quit.desc]}";                      command="${MSG[pv.quit.cmd]}";;
    *)         title="—";;
  esac

  printf '\n  %s%s%s  %s%s%s\n' "$A_ACC" "$C_B" "▸" "$C_B" "$title" "$C_R"
  printf '  %s%s%s\n\n' "$A_FNT" "$(printf '─%.0s' {1..34})" "$C_R"
  [ -n "$desc" ] && printf '  %s\n\n' "${A_MUT}${desc}${C_R}"
  if [ -n "$command" ]; then
    printf '  %s%s%s\n' "$A_MUT" "${MSG[pv.equivalent]}" "$C_R"
    printf '  %s$ %s%s\n\n' "$A_GLOW" "$command" "$C_R"
  fi
  printf '  %s%s%s\n\n' "$A_FNT" "$(printf '─%.0s' {1..34})" "$C_R"

  # Status card. card.* labels are pre-padded to one display width per locale,
  # so these columns line up in both languages.
  if is_running; then
    printf '  %s%s%s  %s● %s%s\n' "$A_MUT" "${MSG[card.service]}" "$C_R" "$A_OK" "${MSG[state.running]}" "$C_R"
    printf '  %s%s%s  %s%s%s\n'    "$A_MUT" "${MSG[card.pid]}"     "$C_R" "$A_TEXT" "$(server_pid)" "$C_R"
  else
    printf '  %s%s%s  %s○ %s%s\n' "$A_MUT" "${MSG[card.service]}" "$C_R" "$A_WARN" "${MSG[state.stopped]}" "$C_R"
    printf '  %s%s%s  %s—%s\n'    "$A_MUT" "${MSG[card.pid]}"     "$C_R" "$A_TEXT" "$C_R"
  fi
  printf '  %s%s%s  %s127.0.0.1:%s%s\n' "$A_MUT" "${MSG[card.addr]}"    "$C_R" "$A_GLOW" "$PORT" "$C_R"
  printf '  %s%s%s  %s%s%s\n'           "$A_MUT" "${MSG[card.version]}" "$C_R" "$A_TEXT" "$(dsh_version)" "$C_R"
  printf '  %s%s%s  %s%s%s\n'           "$A_MUT" "${MSG[card.uptime]}"  "$C_R" "$A_TEXT" "$(server_uptime)" "$C_R"
  printf '\n  %s\n' "$(wave_line $(( $(preview_width) - 6 )))"
}

# --- menu --------------------------------------------------------------------
# Groups are colour-coded: blue = service, cyan = diagnostics, violet = tools,
# grey = exit. The id stays in field 1 so the preview can address it.
build_menu() {
  MENU_ITEMS=(
    "start|${A_ACC}${C_B}▶${C_R}   ${A_TEXT}${C_B}${MSG[menu.start]}${C_R}"
    "stop|${A_ERR}${C_B}■${C_R}   ${A_TEXT}${MSG[menu.stop]}${C_R}"
    "restart|${A_ACC}${C_B}↻${C_R}   ${A_TEXT}${MSG[menu.restart]}${C_R}"
    "open|${A_ACC}${C_B}↗${C_R}   ${A_TEXT}${MSG[menu.open]}${C_R}"
    "status|${A_GLOW}${C_B}◉${C_R}   ${A_TEXT}${MSG[menu.status]}${C_R}"
    "version|${A_GLOW}${C_B}◈${C_R}   ${A_TEXT}${MSG[menu.version]}${C_R}"
    "update|${A_GLOW}${C_B}▼${C_R}   ${A_TEXT}${MSG[menu.update]}${C_R}"
    "logs|${A_GLOW}${C_B}≡${C_R}   ${A_TEXT}${MSG[menu.logs]}${C_R}"
    "headless|${A_VIO}${C_B}▷${C_R}   ${A_TEXT}${MSG[menu.headless]}${C_R}"
    "plugins|${A_VIO}${C_B}▣${C_R}   ${A_TEXT}${MSG[menu.plugins]}${C_R}"
    "config|${A_VIO}${C_B}⌘${C_R}   ${A_TEXT}${MSG[menu.config]}${C_R}"
    "workspace|${A_VIO}${C_B}▢${C_R}   ${A_TEXT}${MSG[menu.workspace]}${C_R}"
    "docs|${A_VIO}${C_B}?${C_R}   ${A_TEXT}${MSG[menu.docs]}${C_R}"
    "language|${A_VIO}${C_B}◑${C_R}   ${A_TEXT}${MSG[menu.language]}${C_R}"
    "quit|${A_MUT}${C_B}×${C_R}   ${A_MUT}${MSG[menu.quit]}${C_R}"
  )
}

run_action() {
  local id="$1"
  case "$id" in
    start|stop|restart|open|status|version|update|logs|headless|plugins|config|workspace|docs|language|quit)
      "do_${id}" ;;
    *) err "$(printf "${MSG[msg.unknown_action]}" "$id")" ;;
  esac
}

fallback_menu() {
  while true; do
    clear
    printf '%s\n\n' "$(header_text)"
    local i=1 item
    for item in "${MENU_ITEMS[@]}"; do
      local plain="${item#*|}"
      plain="$(printf '%s' "$plain" | sed $'s/\x1b\\[[0-9;]*m//g')"
      printf '   %2d)  %s\n' "$i" "$plain"; (( i++ ))
    done
    printf '\n  > '; read -r n || break
    if [ -z "$n" ] || [ "$n" = "q" ]; then break; fi
    if ! [[ "$n" = <-> ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#MENU_ITEMS[@]}" ]; then sleep 1; continue; fi
    clear
    run_action "${MENU_ITEMS[$n]%%|*}"
    pause
  done
  clear
}

interactive() {
  printf '\e]1;%s\a' "${MSG[app.name]}"
  if [ "${DSH_NO_FZF:-0}" = "1" ] || ! command -v fzf >/dev/null 2>&1; then fallback_menu; return 0; fi
  splash
  build_menu
  while true; do
    local sel id
    sel="$(printf '%s\n' "${MENU_ITEMS[@]}" | fzf \
        --ansi --delimiter='|' --with-nth=2 --nth=2 \
        --height=100% --layout=reverse --border=rounded \
        --border-label=" ◈  ${MSG[app.name]} " --border-label-pos=3 \
        --padding=1 --gap=0 \
        --prompt='  ❯ ' --pointer='❯' --marker='✓' --scrollbar='│' \
        --header="$(header_text)" --header-first \
        --footer="${MSG[footer.keys]}" \
        --info=inline-right \
        --preview "'$CC_BIN' __preview {1}" \
        --preview-window="right:${PREVIEW_PCT}%:wrap:border-left" \
        --bind 'ctrl-/:toggle-preview' \
        --bind 'ctrl-r:refresh-preview' \
        --color="$FZF_COLORS")" || break
    [ -z "$sel" ] && break
    id="${sel%%|*}"
    [ "$id" = "quit" ] && break
    clear
    run_action "$id"
    if [ "$id" = "language" ]; then build_menu; continue; fi
    pause
  done
  clear
  printf '\n  %s%s%s\n' "$A_MUT" "${MSG[misc.exit_thanks]}" "$C_R"
  printf '  %s%s%s\n\n' "$C_D" "${MSG[misc.exit_note]}" "$C_R"
}

# --- entry -------------------------------------------------------------------
usage() {
  printf '\n  %s%s%s\n' "$A_ACC" "${MSG[app.name]}" "$C_R"
  printf '  %s\n\n' "${A_MUT}${MSG[app.tagline]}${C_R}"
  printf '  %s\n\n' "${MSG[misc.usage_title]}"
  printf '    %s\n' "${MSG[misc.usage_menu]}"
  printf '    %s\n' 'start|stop|restart|open|status|version|update|logs'
  printf '    %s\n' "${MSG[misc.usage_headless]}"
  printf '    %s\n' "${MSG[misc.usage_plugins]}"
  printf '    %s\n\n' "${MSG[misc.usage_rest]}"
}

cc_main() {
  local action="${1:-}"
  case "$action" in
    ""|menu)        interactive ;;
    __preview)      action_preview "${2:-}" ;;
    __items)        build_menu; printf '%s\n' "${MENU_ITEMS[@]}" ;;
    language|lang)  do_language ;;
    help|-h|--help) usage ;;
    headless)       shift; do_headless "${1:-}" ;;
    plugins)        shift; do_plugins "$@" ;;
    start|stop|restart|open|status|version|update|logs|config|workspace|docs|quit)
                    "do_${action}" ;;
    *)              err "$(printf "${MSG[msg.unknown_command]}" "$action")"; usage; exit 2 ;;
  esac
}
