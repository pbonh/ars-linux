# shellcheck shell=bash
# Phase 4 — distrobox.

ZINSTALL_DISTROBOX_INI="${ZINSTALL_DISTROBOX_INI:-$ZINSTALL_DIR/packages/distroboxes.ini}"

# _parse_sections FILE  → newline-separated section names from an INI.
_parse_sections() {
  awk '/^\[.+\]$/ { gsub(/[][]/,""); print }' "$1"
}

# _section_value FILE SECTION KEY  → value (stripped of surrounding quotes), or empty.
_section_value() {
  awk -v section="$2" -v key="$3" '
    /^\[.+\]$/ { gsub(/[][]/,""); cur=$0; next }
    cur==section && $0 ~ "^"key"=" {
      sub("^"key"=",""); gsub(/^"|"$/,""); print; exit
    }
  ' "$1"
}

_distrobox_exists() {
  distrobox list 2>/dev/null | awk -F'|' 'NR>1 {gsub(/ /,"",$2); print $2}' | grep -qx "$1"
}

run_distrobox() {
  log::section "Phase 4 — distrobox"

  if ! command -v distrobox >/dev/null 2>&1; then
    log::error "distrobox not found — should be present on Zirconium"
    return 1
  fi

  if [[ ! -r "$ZINSTALL_DISTROBOX_INI" ]]; then
    log::warn "no distroboxes.ini at $ZINSTALL_DISTROBOX_INI — skipping"
    return 0
  fi

  local rc=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if _distrobox_exists "$name"; then
      log::info "distrobox '$name' exists; re-exporting declared bins/apps"
      _export_for_section "$name" || rc=1
    else
      _run distrobox-assemble create --file "$ZINSTALL_DISTROBOX_INI" --name "$name" \
        || { log::error "failed to create distrobox '$name'"; rc=1; }
    fi
  done < <(_parse_sections "$ZINSTALL_DISTROBOX_INI")

  return "$rc"
}

# Re-run the export step for an already-existing container.
_export_for_section() {
  local name="$1" bins apps b a
  bins="$(_section_value "$ZINSTALL_DISTROBOX_INI" "$name" exported_bins)"
  apps="$(_section_value "$ZINSTALL_DISTROBOX_INI" "$name" exported_apps)"
  for b in $bins; do
    _run distrobox-export --bin "$b" --export-path "$HOME/.local/bin" --bin-name "$(basename "$b")" \
      || log::warn "export bin $b in $name failed"
  done
  for a in $apps; do
    _run distrobox-export --app "$a" \
      || log::warn "export app $a in $name failed"
  done
}
