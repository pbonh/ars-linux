#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not on PATH yet; skipping (reboot pending after rpm-ostree install)"
  exit 0
fi

if ! systemctl is-enabled --quiet docker.socket 2>/dev/null; then
  sudo systemctl enable --now docker.socket
fi

if ! getent group docker >/dev/null; then
  sudo groupadd -r docker
fi
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to docker group. Log out and back in (or reboot) to pick up the new group."
fi
