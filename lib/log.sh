# shellcheck shell=bash
# Logging primitives for zinstall. Source-only; no top-level side effects.

_zinstall_log_color_enabled() {
  [[ -t 1 && -z "${NO_COLOR:-}" ]]
}

_zinstall_log_paint() {
  local color="$1"; shift
  if _zinstall_log_color_enabled; then
    printf '\e[%sm%s\e[0m' "$color" "$*"
  else
    printf '%s' "$*"
  fi
}

log::info()    { printf '%s %s\n' "$(_zinstall_log_paint 36 '[INFO]')" "$*"; }
log::ok()      { printf '%s %s\n' "$(_zinstall_log_paint 32 '[OK]')"   "$*"; }
log::warn()    { printf '%s %s\n' "$(_zinstall_log_paint 33 '[WARN]')" "$*" >&2; }
log::error()   { printf '%s %s\n' "$(_zinstall_log_paint 31 '[ERROR]')" "$*" >&2; }
log::section() {
  local bar="================================================================"
  printf '\n%s\n%s %s\n%s\n' "$bar" "$(_zinstall_log_paint 35 '==')" "$*" "$bar"
}

# _run cmd...  — print and execute, or print-only when DRY_RUN=1.
_run() {
  if [[ "${VERBOSE:-0}" == 1 ]]; then
    log::info "+$(printf ' %q' "$@")"
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    log::info "[dry-run] $*"
    return 0
  fi
  "$@"
}

log::start_run() {
  local dir="$HOME/.cache/zinstall"
  mkdir -p "$dir"
  find "$dir" -maxdepth 1 -type f -name 'run-*.log' -mtime +30 -delete 2>/dev/null || true
  ZINSTALL_RUN_LOG="$dir/run-$(date +%Y%m%dT%H%M%S).log"
  export ZINSTALL_RUN_LOG
  : >"$ZINSTALL_RUN_LOG"
}

# _retry cmd...  — run with up to 3 attempts and exponential backoff (1s, 2s, 4s).
# Delegates to _run, so DRY_RUN/VERBOSE handling is inherited.
_retry() {
  local n=0 max=3 delay=1
  while (( n < max )); do
    if _run "$@"; then return 0; fi
    n=$((n+1))
    if (( n < max )); then
      log::warn "command failed (attempt $n/$max), retrying in ${delay}s: $*"
      sleep "$delay"
      delay=$((delay*2))
    fi
  done
  log::error "command failed after $max attempts: $*"
  return 1
}
