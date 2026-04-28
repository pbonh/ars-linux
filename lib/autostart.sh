# shellcheck shell=bash
# Phase 5 — autostart units under systemd --user, namespaced 'zinstall-*'.

ZINSTALL_AUTOSTART_LIST="${ZINSTALL_AUTOSTART_LIST:-$ZINSTALL_DIR/packages/autostart.list}"
ZINSTALL_AUTOSTART_DIR="$HOME/.config/systemd/user"

# _autostart_slug LINE → slug
_autostart_slug() {
  local line="$1"
  if [[ "$line" == *=* && "${line%%=*}" =~ ^[a-z0-9-]+$ ]]; then
    echo "${line%%=*}"
  else
    local cmd="${line%% *}"
    basename "$cmd"
  fi
}

# _autostart_command LINE → command
_autostart_command() {
  local line="$1"
  if [[ "$line" == *=* && "${line%%=*}" =~ ^[a-z0-9-]+$ ]]; then
    echo "${line#*=}"
  else
    echo "$line"
  fi
}

_autostart_unit_body() {
  local slug="$1" cmd="$2"
  cat <<EOF
[Unit]
Description=zinstall-managed autostart: $slug
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$cmd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF
}

run_autostart() {
  log::section "Phase 5 — autostart"
  mkdir -p "$ZINSTALL_AUTOSTART_DIR"

  local declared=()
  if [[ -r "$ZINSTALL_AUTOSTART_LIST" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      local slug cmd
      slug="$(_autostart_slug "$line")"
      cmd="$(_autostart_command "$line")"
      declared+=("$slug")
      _autostart_write_and_enable "$slug" "$cmd"
    done <"$ZINSTALL_AUTOSTART_LIST"
  fi

  if [[ "${PRUNE:-0}" == 1 ]]; then
    _autostart_prune ${declared[@]+"${declared[@]}"}
  fi
  log::ok "autostart units up to date"
}

_autostart_write_and_enable() {
  local slug="$1" cmd="$2"
  local unit="$ZINSTALL_AUTOSTART_DIR/zinstall-$slug.service"
  local desired
  desired="$(_autostart_unit_body "$slug" "$cmd")"
  if [[ -f "$unit" ]] && [[ "$(cat "$unit")" == "$desired" ]]; then
    log::info "unit zinstall-$slug.service unchanged"
  else
    if [[ "${DRY_RUN:-0}" == 1 ]]; then
      log::info "[dry-run] write $unit"
    else
      printf '%s\n' "$desired" >"$unit"
    fi
  fi
  _run systemctl --user daemon-reload
  if ! systemctl --user is-active --quiet "zinstall-$slug.service" 2>/dev/null; then
    _run systemctl --user enable --now "zinstall-$slug.service"
  fi
}

_autostart_prune() {
  local keep=("$@")
  shopt -s nullglob
  local f base slug skip
  for f in "$ZINSTALL_AUTOSTART_DIR"/zinstall-*.service; do
    base="$(basename "$f")"
    slug="${base#zinstall-}"; slug="${slug%.service}"
    skip=0
    for k in "${keep[@]}"; do [[ "$k" == "$slug" ]] && skip=1; done
    if [[ "$skip" == 0 ]]; then
      _run systemctl --user disable --now "zinstall-$slug.service" || true
      _run rm -f "$f"
      log::info "pruned zinstall-$slug.service"
    fi
  done
}
