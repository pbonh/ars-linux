# shellcheck shell=bash
# Phase 1 — install Homebrew if missing. Phase 3 (run_brewfile) lives in this
# same file and is added in a later task.

ZINSTALL_BREW_INSTALL_URL="${ZINSTALL_BREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"
ZINSTALL_LINUXBREW_PREFIX="${ZINSTALL_LINUXBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"

_brew_present() {
  # Allow overriding for testing (when system brew would interfere)
  [[ "${ZINSTALL_BREW_MISSING:-0}" == "1" ]] && return 1
  command -v brew >/dev/null 2>&1 || [[ -x "$ZINSTALL_LINUXBREW_PREFIX/bin/brew" ]]
}

_brew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  elif [[ -x "$ZINSTALL_LINUXBREW_PREFIX/bin/brew" ]]; then
    eval "$("$ZINSTALL_LINUXBREW_PREFIX/bin/brew" shellenv)"
  fi
}

run_brew_install() {
  log::section "Phase 1 — Homebrew"
  if _brew_present; then
    log::info "brew already installed"
    _brew_shellenv
    log::ok "brew ready"
    return 0
  fi

  log::info "installing Homebrew non-interactively"
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    log::info "[dry-run] curl -fsSL $ZINSTALL_BREW_INSTALL_URL | NONINTERACTIVE=1 bash"
    return 0
  fi

  local installer
  installer="$(_retry curl -fsSL "$ZINSTALL_BREW_INSTALL_URL")" || {
    log::error "failed to fetch Homebrew installer"; return 1
  }
  NONINTERACTIVE=1 bash -c "$installer" || {
    log::error "Homebrew installer failed"; return 1
  }
  _brew_shellenv
  log::ok "brew installed"
}
