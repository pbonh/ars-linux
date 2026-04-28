#!/usr/bin/env bash
set -Eeuo pipefail

if ! flatpak --user remotes --columns=name | grep -qx flathub; then
  flatpak remote-add --user --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
fi
