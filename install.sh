#!/usr/bin/env bash
# zinstall — bring a Zirconium box to its declared state.

set -Eeuo pipefail

ZINSTALL_REPO_URL="${ZINSTALL_REPO_URL:-https://github.com/pbonh/ars-linux.git}"
ZINSTALL_CHECKOUT="${ZINSTALL_CHECKOUT:-$HOME/.local/share/zinstall}"

# Bootstrap: when invoked via `curl ... | bash`, BASH_SOURCE[0] is unset.
# Clone the repo to a stable location and re-exec the local copy.
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]:-}" == "bash" ]] || [[ "${BASH_SOURCE[0]:-}" == "/dev/stdin" ]]; then
  if [[ ! -d "$ZINSTALL_CHECKOUT/.git" ]]; then
    mkdir -p "$(dirname "$ZINSTALL_CHECKOUT")"
    git clone --depth 1 "$ZINSTALL_REPO_URL" "$ZINSTALL_CHECKOUT"
  else
    git -C "$ZINSTALL_CHECKOUT" pull --ff-only --quiet || true
  fi
  exec bash "$ZINSTALL_CHECKOUT/install.sh" "$@"
fi

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
    -v|--verbose) VERBOSE=1 ;;
    --only=*) ONLY="${1#*=}" ;;
    --skip=*) SKIP="${1#*=}" ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -n "$ONLY" && -n "$SKIP" ]]; then
  echo "--only and --skip are mutually exclusive" >&2; exit 2
fi

[[ "$VERBOSE" == 1 ]] && set -x

# --- begin phase dispatch ---
log::start_run
# Tee all subsequent stdout/stderr to the run log (spec §10).
exec > >(tee -a "$ZINSTALL_RUN_LOG") 2>&1
log::info "zinstall starting (dry-run=$DRY_RUN upgrade=$UPGRADE prune=$PRUNE)"

REBOOT_NEEDED=0
export REBOOT_NEEDED

# Source phase modules.
for mod in preflight brew chezmoi distrobox autostart layered postinstall system; do
  # shellcheck source=/dev/null
  source "$ZINSTALL_DIR/lib/${mod}.sh"
done

declare -A PHASES=(
  [preflight]=run_preflight
  [brew]=run_brew_install
  [chezmoi]=run_chezmoi
  [brewfile]=run_brewfile
  [distrobox]=run_distrobox
  [autostart]=run_autostart
  [layered]=run_layered
  [postinstall]=run_postinstall
  [system]=run_system_upgrade
)
PHASE_ORDER=(preflight brew chezmoi brewfile distrobox autostart layered postinstall system)
SELECTABLE=(brew chezmoi brewfile distrobox autostart layered postinstall system)

_phase_selected() {
  local p="$1"
  if [[ -n "$ONLY" ]]; then
    [[ ",$ONLY," == *",$p,"* ]]
  elif [[ -n "$SKIP" ]]; then
    [[ ",$SKIP," != *",$p,"* ]]
  else
    return 0
  fi
}

# Validate phase names.
_validate_phase_list() {
  local list="$1" name
  IFS=',' read -ra names <<<"$list"
  for name in "${names[@]}"; do
    local found=0
    for s in "${SELECTABLE[@]}"; do [[ "$s" == "$name" ]] && found=1; done
    if [[ "$found" == 0 ]]; then
      echo "unknown phase: $name" >&2
      exit 2
    fi
  done
}
[[ -n "$ONLY" ]] && _validate_phase_list "$ONLY"
[[ -n "$SKIP" ]] && _validate_phase_list "$SKIP"

declare -A PHASE_STATUS=()
EXIT_CODE=0

# preflight always runs unless --only is in effect.
if [[ -z "$ONLY" ]]; then
  if run_preflight; then PHASE_STATUS[preflight]=ok
  else PHASE_STATUS[preflight]=fail; EXIT_CODE=1; fi
fi

for p in "${SELECTABLE[@]}"; do
  if _phase_selected "$p"; then
    if "${PHASES[$p]}"; then
      PHASE_STATUS[$p]=ok
    else
      PHASE_STATUS[$p]=fail
      EXIT_CODE=1
    fi
  else
    PHASE_STATUS[$p]=skip
  fi
done

# Phase 8 — summary.
log::section "Summary"
for p in "${PHASE_ORDER[@]}"; do
  printf '  %-12s %s\n' "$p" "${PHASE_STATUS[$p]:-skip}"
done

if [[ "${REBOOT_NEEDED:-0}" == 1 ]]; then
  if [[ "$NO_REBOOT_PROMPT" != 1 && -t 0 ]]; then
    read -rp "Reboot now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      _run systemctl reboot
    else
      log::warn "reboot pending — apply when convenient"
    fi
  else
    log::warn "reboot pending — apply when convenient"
  fi
fi

exit "$EXIT_CODE"
# --- end phase dispatch ---
