# shellcheck shell=bash
# Phase 2 — chezmoi. Pulls dotfiles from pbonh/zdots.

ZINSTALL_DOTFILES_REPO="${ZINSTALL_DOTFILES_REPO:-pbonh/zdots}"

run_chezmoi() {
  log::section "Phase 2 — chezmoi"

  if ! command -v chezmoi >/dev/null 2>&1; then
    log::info "installing chezmoi via brew"
    _run brew install chezmoi || { log::error "brew install chezmoi failed"; return 1; }
  fi

  local src="$HOME/.local/share/chezmoi"
  if [[ ! -d "$src/.git" ]]; then
    _run chezmoi init --apply "$ZINSTALL_DOTFILES_REPO" \
      || { log::error "chezmoi init failed"; return 1; }
    log::ok "chezmoi initialized from $ZINSTALL_DOTFILES_REPO"
    return 0
  fi

  if [[ "${UPGRADE:-0}" == 1 ]]; then
    _run chezmoi update || { log::error "chezmoi update failed"; return 1; }
  else
    _run chezmoi apply  || { log::error "chezmoi apply failed"; return 1; }
  fi
  log::ok "chezmoi state enforced"
}
