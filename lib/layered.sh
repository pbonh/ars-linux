# shellcheck shell=bash
# Phase 6 — rpm-ostree layered packages and dnf .repo file drops.

ZINSTALL_LAYERED_LIST="${ZINSTALL_LAYERED_LIST:-$ZINSTALL_DIR/packages/layered.txt}"
ZINSTALL_REPOS_DIR="${ZINSTALL_REPOS_DIR:-$ZINSTALL_DIR/packages/repos}"
ZINSTALL_YUM_REPOS_D="${ZINSTALL_YUM_REPOS_D:-/etc/yum.repos.d}"

_sha256_file() { sha256sum "$1" | awk '{print $1}'; }

_drop_repo_files() {
  shopt -s nullglob
  local src dst
  for src in "$ZINSTALL_REPOS_DIR"/*.repo; do
    dst="$ZINSTALL_YUM_REPOS_D/$(basename "$src")"
    if [[ -f "$dst" ]] && [[ "$(_sha256_file "$src")" == "$(_sha256_file "$dst")" ]]; then
      log::info "repo $(basename "$src") unchanged"
      continue
    fi
    _run sudo install -m 0644 "$src" "$dst" \
      || { log::error "failed to install $src"; return 1; }
  done
}

_currently_layered() {
  rpm-ostree status --json 2>/dev/null \
    | jq -r '.deployments[0]["requested-packages"][]?' 2>/dev/null \
    || true
}

_layering_locked() {
  local conf="${ZINSTALL_RPM_OSTREED_CONF:-/etc/rpm-ostreed.conf}"
  [[ -r "$conf" ]] && grep -Eq '^[[:space:]]*LockLayering[[:space:]]*=[[:space:]]*true' "$conf"
}

_read_declared_layered() {
  local f="$ZINSTALL_LAYERED_LIST"
  [[ -r "$f" ]] || return 0
  awk '
    { sub(/#.*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); }
    NF { print }
  ' "$f"
}

run_layered() {
  log::section "Phase 6 — layered packages"

  _drop_repo_files || return 1

  if _layering_locked; then
    log::error "rpm-ostree LockLayering=true — cannot install declared packages."
    log::error "  Run the two commands in README.md → 'Prerequisite: enable rpm-ostree layering'"
    log::error "  to disable LockLayering, then re-run zinstall."
    return 1
  fi

  local declared current to_add to_remove
  declared="$(_read_declared_layered | sort -u)"
  current="$(_currently_layered | sort -u)"
  to_add="$(comm -23 <(echo "$declared") <(echo "$current") | tr '\n' ' ')"
  to_remove="$(comm -13 <(echo "$declared") <(echo "$current") | tr '\n' ' ')"

  if [[ -n "${to_add// }" ]]; then
    # shellcheck disable=SC2086
    _run sudo rpm-ostree install --idempotent --allow-inactive $to_add \
      || { log::error "rpm-ostree install failed"; return 1; }
    REBOOT_NEEDED=1
    export REBOOT_NEEDED
  else
    log::info "no new layered packages to install"
  fi

  if [[ "${PRUNE:-0}" == 1 && -n "${to_remove// }" ]]; then
    # shellcheck disable=SC2086
    _run sudo rpm-ostree uninstall $to_remove \
      || { log::error "rpm-ostree uninstall failed"; return 1; }
    REBOOT_NEEDED=1
    export REBOOT_NEEDED
  fi

  log::ok "layered package set converged"
}
