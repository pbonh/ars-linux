repo := "https://github.com/pbonh/ars-linux.git"

default:
    @just --list

# Authenticate sudo, keep the timestamp cache warm in the background, then
# run ansible-pull. ansible.cfg sets `become_flags = -n` so ansible uses the
# cached credentials non-interactively — no prompt-detection race.
_sudo-keepalive:
    @sudo -v
    @( while true; do sudo -n true; sleep 60; kill -0 "$(echo $$)" 2>/dev/null || exit; done ) &

sync: _sudo-keepalive
    ansible-pull -U {{repo}} system.yml

sync-user:
    ansible-pull -U {{repo}} user.yml

sync-flatpaks: _sudo-keepalive
    ansible-pull -U {{repo}} system.yml --tags flatpaks

sync-tags TAGS: _sudo-keepalive
    ansible-pull -U {{repo}} system.yml --tags "{{TAGS}}"

lint:
    yamllint .
    ansible-lint roles/ system.yml user.yml

test:
    pytest

vm-test BRANCH="main":
    @echo "Boot a Zirconium ISO in quickemu, then inside the guest:"
    @echo "  sudo dnf install -y ansible-core git"
    @echo "  sudo -v && ansible-pull -U {{repo}} --checkout \"{{BRANCH}}\" system.yml"

bump-vivaldi VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    url="https://downloads.vivaldi.com/stable/vivaldi-stable-{{VERSION}}.x86_64.rpm"
    sha=$(curl -fsSL "$url" | sha256sum | awk '{print $1}')
    echo "Vivaldi $url -> sha256:$sha"
    sed -i "s|^ars_vivaldi_version:.*|ars_vivaldi_version: \"{{VERSION}}\"|" \
        roles/third_party_rpms/defaults/main.yml
    sed -i "s|^ars_vivaldi_sha256:.*|ars_vivaldi_sha256: \"$sha\"|" \
        roles/third_party_rpms/defaults/main.yml

bump-cursor VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    url="https://downloader.cursor.sh/linux/appImage/x64?version={{VERSION}}"
    sha=$(curl -fsSL "$url" | sha256sum | awk '{print $1}')
    echo "Cursor $url -> sha256:$sha"
    sed -i "s|^ars_cursor_version:.*|ars_cursor_version: \"{{VERSION}}\"|" \
        roles/appimages/defaults/main.yml
    sed -i "s|^ars_cursor_sha256:.*|ars_cursor_sha256: \"$sha\"|" \
        roles/appimages/defaults/main.yml

bump-protonmail URL:
    #!/usr/bin/env bash
    set -euo pipefail
    sha=$(curl -fsSL "{{URL}}" | sha256sum | awk '{print $1}')
    echo "ProtonMail {{URL}} -> sha256:$sha"
    sed -i "s|^ars_protonmail_rpm_url:.*|ars_protonmail_rpm_url: \"{{URL}}\"|" \
        roles/distrobox/defaults/main.yml
    sed -i "s|^ars_protonmail_rpm_sha256:.*|ars_protonmail_rpm_sha256: \"$sha\"|" \
        roles/distrobox/defaults/main.yml
