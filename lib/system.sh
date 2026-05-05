# shellcheck shell=bash
# Phase 7 — system image upgrade. Uses bootc on a clean deployment; falls back
# to rpm-ostree upgrade when layered packages are present (bootc refuses to
# upgrade a deployment with local rpm-ostree modifications). Only runs when
# UPGRADE=1.

_has_layered_packages() {
  local n
  n="$(rpm-ostree status --json 2>/dev/null \
        | jq -r '.deployments[0]["requested-packages"] | length' 2>/dev/null \
        || echo 0)"
  [[ "${n:-0}" -gt 0 ]]
}

run_system_upgrade() {
  if [[ "${UPGRADE:-0}" != 1 ]]; then
    log::info "Phase 7 — system upgrade skipped (no --upgrade)"
    return 0
  fi

  local tool
  if _has_layered_packages; then
    tool="rpm-ostree"
    log::section "Phase 7 — rpm-ostree upgrade (layered deployment)"
  else
    tool="bootc"
    log::section "Phase 7 — bootc upgrade"
  fi

  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    if [[ "$tool" == "rpm-ostree" ]]; then
      log::info "[dry-run] sudo rpm-ostree upgrade"
    else
      log::info "[dry-run] sudo bootc upgrade"
    fi
    return 0
  fi

  local out
  if [[ "$tool" == "rpm-ostree" ]]; then
    out="$(sudo rpm-ostree upgrade 2>&1)" \
      || { log::error "rpm-ostree upgrade failed: $out"; return 1; }
  else
    out="$(sudo bootc upgrade 2>&1)" \
      || { log::error "bootc upgrade failed: $out"; return 1; }
  fi
  printf '%s\n' "$out"

  if grep -Eqi 'staging|staged|new deployment|queued for next boot' <<<"$out"; then
    REBOOT_NEEDED=1
    export REBOOT_NEEDED
  fi
  log::ok "system upgrade phase done ($tool)"
}
