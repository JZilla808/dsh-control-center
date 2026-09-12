# =============================================================================
#  dsh-control-center · i18n
#
#  Message catalogs are plain zsh associative arrays keyed by stable ids, one
#  file per locale under ../locales/. English is always loaded first and the
#  active locale is merged over it, so a key missing from a translation falls
#  back to English instead of disappearing. That mirrors the lookup rule of
#  DeepSeek Harness's own locale plugin (walk the fallback chain, then show the
#  key itself).
#
#  Language resolution order (first hit wins):
#    1. $DSH_LANG                    explicit override, e.g. DSH_LANG=en
#    2. the stored preference        $DSH_CC_HOME/lang
#    3. the environment              $LC_ALL / $LC_MESSAGES / $LANG  (zh* -> zh)
#    4. en
#
#  A prompt is only shown when nothing above could decide AND the session is a
#  terminal AND no preference file exists yet. After the first run the choice is
#  remembered, so the picker never appears again unless the user clears it.
# =============================================================================

typeset -A MSG          # resolved catalog (en base + active locale overlay)
MSG_LANG=""             # the locale actually in use: "en" | "zh"
MSG_LANG_EXPLICIT=0     # 1 when it came from $DSH_LANG or the stored preference

# Supported locales. `zh` and `en` deliberately match DeepSeek Harness's own
# shipped set (dsh-client-locale LOCALE_IDS), so we do not invent a third.
SUPPORTED_LANGS=(en zh)

# --- display width -----------------------------------------------------------
# CJK glyphs occupy two terminal columns. Pad/measure with this rather than
# ${#s}, or the bilingual layouts drift apart.
cc_width() {
  local s="$1" n=0 c
  for c in ${(s::)s}; do
    case "$c" in
      ([一-鿿]|[　-〿]|[＀-￯]|[぀-ゟ]|[゠-ヿ]) (( n += 2 )) ;;
      (*) (( n += 1 )) ;;
    esac
  done
  printf '%s' "$n"
}

# Right-pad to a display width (used to keep the status card columns aligned
# across locales).
cc_pad() {
  local s="$1" want="$2" have
  have=$(cc_width "$s")
  printf '%s' "$s"
  while [ "$have" -lt "$want" ]; do printf ' '; (( have++ )); done
}

# --- catalog loading ---------------------------------------------------------
_cc_load_locale() {  # $1 = locale id; calls _cc_locale_<id> which fills _CC_L
  local fn="_cc_locale_$1"
  if (( ! ${+functions[$fn]} )); then
    return 1
  fi
  typeset -gA _CC_L=()
  "$fn"
  local k
  for k in ${(k)_CC_L}; do MSG[$k]="${_CC_L[$k]}"; done
  return 0
}

cc_load_messages() {  # $1 = locale id
  typeset -gA MSG=()
  _cc_load_locale en || { print -u2 "dsh-control-center: missing locale 'en'"; return 1 }
  if [ "$1" != "en" ]; then
    _cc_load_locale "$1" || return 1
  fi
  typeset -g MSG_LANG="$1"
  return 0
}

# --- resolution --------------------------------------------------------------
# Returns a locale id, or nothing when the environment genuinely does not say.
# "Undetermined" is what lets the one-time picker appear; defaulting to `en`
# here would silently suppress it forever.
_cc_lang_from_env() {
  local v="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  [ -z "$v" ] && return 0
  case "$v" in
    C|POSIX|C.UTF-8|C.utf8)  return 0 ;;
    zh*|*_CN*|*_SG*|*_Hans*) printf 'zh' ;;
    *)                       printf 'en' ;;
  esac
}

cc_lang_dir()  { printf '%s' "${DSH_CC_HOME:-$HOME/.dsh-control-center}"; }
cc_lang_file() { printf '%s/lang' "$(cc_lang_dir)"; }

cc_store_lang() {  # $1 = locale id
  local d; d="$(cc_lang_dir)"
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s\n' "$1" > "$(cc_lang_file)" 2>/dev/null || true
}

cc_resolve_lang() {
  local want=""

  # 1. explicit override
  if [ -n "${DSH_LANG:-}" ]; then
    want="${DSH_LANG%%[_@.-]*}"
    case " ${SUPPORTED_LANGS[*]} " in
      (*" $want "*) MSG_LANG_EXPLICIT=1; printf '%s' "$want"; return 0 ;;
      (*)           : ;;   # unknown -> keep looking
    esac
  fi

  # 2. stored preference
  local f; f="$(cc_lang_file)"
  if [ -s "$f" ]; then
    want="$(head -n1 "$f" 2>/dev/null | tr -d '[:space:]')"
    case " ${SUPPORTED_LANGS[*]} " in
      (*" $want "*) MSG_LANG_EXPLICIT=1; printf '%s' "$want"; return 0 ;;
    esac
  fi

  # 3. environment
  printf '%s' "$(_cc_lang_from_env)"
}
