#!/usr/bin/env bash
# zinstall — bring a Zirconium box to its declared state.

set -Eeuo pipefail

ZINSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ZINSTALL_DIR

# shellcheck source=lib/log.sh
source "$ZINSTALL_DIR/lib/log.sh"

trap 'log::error "failed at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}"' ERR

usage() {
  cat <<'EOF'
install.sh [flags]

  --upgrade              Run brew bundle upgrade, chezmoi update, and bootc upgrade.
  --dry-run              Print every state-changing command, do not execute.
  --no-reboot-prompt     Suppress the reboot question; just report.
  --prune                Remove items no longer declared:
                           - layered packages no longer in layered.txt
                           - systemd autostart units no longer in autostart.list
                           - Brewfile entries via 'brew bundle cleanup'
  --only=<phase[,...]>   Run only listed phases. Names: brew, chezmoi, brewfile,
                         distrobox, autostart, layered, postinstall, system.
  --skip=<phase[,...]>   Skip listed phases.
  -v, --verbose          Show every command before running it.
  -h, --help             Print usage and exit 0.
EOF
}

# Defaults
DRY_RUN=0; UPGRADE=0; PRUNE=0; VERBOSE=0; NO_REBOOT_PROMPT=0
ONLY=""; SKIP=""
export DRY_RUN UPGRADE PRUNE VERBOSE NO_REBOOT_PROMPT

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --upgrade) UPGRADE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-reboot-prompt) NO_REBOOT_PROMPT=1 ;;
    --prune) PRUNE=1 ;;
    -v|--verbose) VERBOSE=1; set -x ;;
    --only=*) ONLY="${1#*=}" ;;
    --skip=*) SKIP="${1#*=}" ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -n "$ONLY" && -n "$SKIP" ]]; then
  echo "--only and --skip are mutually exclusive" >&2; exit 2
fi

# Phase dispatch table (filled in over later tasks).
log::info "zinstall: parsed flags (placeholder — phases not wired yet)"
