#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v tailscale >/dev/null 2>&1; then
  echo "tailscale not on PATH yet; skipping (reboot pending after rpm-ostree install)"
  exit 0
fi

if ! systemctl is-enabled --quiet tailscaled 2>/dev/null; then
  sudo systemctl enable --now tailscaled
fi
