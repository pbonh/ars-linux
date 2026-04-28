# shellcheck shell=bash
# Phase 7 — system image upgrade via bootc. Only runs when UPGRADE=1.

run_system_upgrade() {
  if [[ "${UPGRADE:-0}" != 1 ]]; then
    log::info "Phase 7 — bootc upgrade skipped (no --upgrade)"
    return 0
  fi
  log::section "Phase 7 — bootc upgrade"
  local out
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    log::info "[dry-run] sudo bootc upgrade"
    return 0
  fi
  out="$(sudo bootc upgrade 2>&1)" || { log::error "bootc upgrade failed: $out"; return 1; }
  printf '%s\n' "$out"
  if grep -Eqi 'staged|new deployment' <<<"$out"; then
    REBOOT_NEEDED=1
    export REBOOT_NEEDED
  fi
  log::ok "system upgrade phase done"
}
