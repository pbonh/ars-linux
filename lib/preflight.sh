# shellcheck shell=bash
# Phase 0 — system preflight.

# Helper to get effective UID (can be overridden via ZINSTALL_EUID in tests)
_get_euid() {
  echo "${ZINSTALL_EUID:-${EUID:-$(id -u)}}"
}

run_preflight() {
  log::section "Phase 0 — preflight"

  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    log::info "[dry-run] preflight checks skipped"
    return 0
  fi

  local uid
  uid=$(_get_euid)
  if [[ "$uid" -eq 0 ]]; then
    log::error "do not run zinstall as root"
    return 1
  fi

  if ! command -v bootc >/dev/null 2>&1; then
    log::error "bootc not found — this script requires a bootc-based host"
    return 1
  fi

  local osr="${ZINSTALL_OS_RELEASE:-/etc/os-release}"
  if [[ ! -r "$osr" ]]; then
    log::error "cannot read $osr"
    return 1
  fi
  if ! grep -Eq '^(ID=fedora|ID_LIKE=.*fedora.*)' "$osr"; then
    log::error "host is not Fedora-family (need ID=fedora or ID_LIKE containing fedora)"
    return 1
  fi

  if ! _retry curl -fsSI --max-time 10 https://github.com >/dev/null 2>&1; then
    log::error "network check failed (cannot reach https://github.com)"
    return 1
  fi

  if ! sudo -v >/dev/null 2>&1; then
    log::error "sudo is required and could not be primed"
    return 1
  fi

  # Background sudo keep-alive — dies with the script.
  # Set ZINSTALL_SKIP_KEEPALIVE=1 to disable (e.g. in tests).
  if [[ "${ZINSTALL_SKIP_KEEPALIVE:-0}" != 1 ]]; then
    ( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    ZINSTALL_SUDO_KEEPALIVE_PID=$!
    export ZINSTALL_SUDO_KEEPALIVE_PID
  fi

  log::ok "preflight checks passed"
}
