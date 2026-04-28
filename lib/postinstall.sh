# shellcheck shell=bash
# Phase 6.5 — post-install hooks.

ZINSTALL_POSTINSTALL_DIR="${ZINSTALL_POSTINSTALL_DIR:-$ZINSTALL_DIR/packages/post-install.d}"

run_postinstall() {
  log::section "Phase 6.5 — post-install hooks"
  if [[ ! -d "$ZINSTALL_POSTINSTALL_DIR" ]]; then
    log::info "no post-install.d directory; skipping"
    return 0
  fi

  local rc=0 script
  shopt -s nullglob
  local scripts=("$ZINSTALL_POSTINSTALL_DIR"/*.sh)
  IFS=$'\n' scripts=($(printf '%s\n' "${scripts[@]}" | sort)); unset IFS

  for script in "${scripts[@]}"; do
    [[ -f "$script" ]] || continue
    log::info "running $(basename "$script")"
    if [[ "${DRY_RUN:-0}" == 1 ]]; then
      log::info "[dry-run] bash $script"
      continue
    fi
    if ! bash -e -u -o pipefail "$script"; then
      log::error "post-install script $(basename "$script") failed"
      rc=1
    fi
  done
  return "$rc"
}
