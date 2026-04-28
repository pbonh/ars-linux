#!/usr/bin/env bash
# Move /opt/{brave.com,vivaldi,cursor} to /usr/lib and rewrite desktop entries.
# bootc images cannot keep app payloads under /opt (it's mutable at runtime),
# so anything that ships there gets relocated at build time.
#
# ARS_RELOCATE_ROOT lets the unit test stage a fake filesystem; production
# leaves it unset so the script operates on the real / .
set -euo pipefail

ROOT="${ARS_RELOCATE_ROOT:-}"
APPS=("brave.com" "vivaldi" "cursor")

for app in "${APPS[@]}"; do
    src="${ROOT}/opt/${app}"
    dst="${ROOT}/usr/lib/${app}"
    [ -d "$src" ] || continue
    mkdir -p "${ROOT}/usr/lib"
    mv "$src" "$dst"

    # Rewrite Exec= lines in any .desktop files that point at the old path.
    if [ -d "${ROOT}/usr/share/applications" ]; then
        find "${ROOT}/usr/share/applications" -maxdepth 1 -name '*.desktop' -print0 |
            xargs -0 -r perl -i -pe "s|\Q/opt/${app}\E|/usr/lib/${app}|g"
    fi
done
