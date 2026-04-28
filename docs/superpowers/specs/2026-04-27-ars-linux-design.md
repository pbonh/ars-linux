# ars-linux design

**Date:** 2026-04-27
**Status:** Approved (brainstorming) — pending implementation plan
**Author:** pbonh

## Goal

Replace the maintenance burden of forking [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium) with an Ansible-driven layer that applies the same customizations on top of an unmodified upstream Zirconium boot image. The result is a personal but multi-host setup that:

- Boots directly from `ghcr.io/zirconium-dev/zirconium:latest` (or `zirconium-nvidia:latest`).
- Builds a small **local-only** derived OCI image containing the customizations.
- Uses `bootc switch` to atomically activate the derived image, so RPM layering, third-party RPMs, AppImages, fonts, and config drops are all immutable in `/usr` and survive `bootc upgrade`.
- Manages user-level state (distrobox containers, `chezmoi`-applied dotfiles via `pbonh/zdots`) through a separate user-context playbook.

ars-linux is the **delivery mechanism**; install paths, branding, and the chezmoi-based dotfiles model deliberately mirror upstream Zirconium so unmodified `pbonh/zdots` works as-is.

## Non-goals

- Publishing a derived image to a public registry. Builds stay in local `containers-storage`.
- Automated unattended updates or scheduled rebuilds. The user runs `ansible-pull` manually.
- Pinning specific upstream Zirconium digests. The base image tracks `:latest`.
- Owning ISO build (`iso.toml`, `iso-nvidia.toml`). Those stay upstream.
- Adding new cosign signing infrastructure. Existing trust of upstream Zirconium images is preserved.
- Reusability for users on other bootc distributions (Bluefin, Bazzite, Silverblue). Roles assume Zirconium.

## Architecture

### Data flow

```
git push to ars-linux                     (laptop)
        ↓
$ sudo -v && \
  ansible-pull -U ars-linux system.yml    (each host, on demand; sudo
                                          authenticated once, ansible
                                          escalates per-task non-interactively)
        ↓
1. dnf_repos                              writes /etc/yum.repos.d/*.repo
2. bootc_image                            renders Containerfile FROM
                                          ghcr.io/zirconium-dev/zirconium:latest,
                                          stages repos/keys, runs `podman build`,
                                          tags `localhost/ars-linux:latest`
3. bootc_image                            `bootc switch --transport containers-storage
                                          localhost/ars-linux:latest` if digest changed
4. profile_d, flatpaks, systemd_user,     drop files into /etc and /usr/share, enable
   services, containers_policy, fonts     services
        ↓
reboot (when image switched)              new bootc deployment becomes default
        ↓
$ ansible-pull -U ars-linux user.yml      (each host, normal user, on demand)
        ↓
5. distrobox                              creates ProtonMail distrobox if missing,
                                          runs `distrobox-export` for desktop integration
6. systemd_user (user side)               `systemctl --user daemon-reload`
        ↓
chezmoi-init.service / chezmoi-update.timer  (system-shipped, preset-enabled)
                                          apply pbonh/zdots from /usr/share/zirconium/zdots
                                          into $HOME on login and on a timer
```

### Key invariants

- **Base image is unmodified upstream.** No fork. `bootc upgrade` rolls forward whatever upstream cuts.
- **Derived image lives only in local containers-storage.** No registry push, no ghcr.io credentials needed, no public exposure.
- **Anything that needs to live in `/usr` goes into the Containerfile.** Anything that's fine in mutable `/etc` is dropped by Ansible at runtime. The split is explicit per-role.
- **Two execution contexts: root (`system.yml`) and user (`user.yml`).** They are independent — running them in either order is safe; missing prerequisites produce warnings, not errors.
- **Install paths mirror upstream Zirconium** (notably `/usr/share/zirconium/zdots/`) so `pbonh/zdots`'s hardcoded paths in `dot_config/niri/*` continue to work.

## Repository layout

```
ars-linux/
├── README.md
├── Justfile                       # `just sync`, `just sync-user`, `just sync-flatpaks`
├── ansible.cfg                    # roles_path, defaults, `gather_subset = !all,min`
├── system.yml                     # root playbook (escalates via become; run after `sudo -v`)
├── user.yml                       # user playbook
├── host_vars/
│   ├── laptop.yml
│   ├── workstation.yml
│   └── nvidia-box.yml
├── group_vars/
│   └── all.yml                    # username, base image ref, default toggles
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-04-27-ars-linux-design.md
└── roles/
    ├── bootc_image/
    ├── dnf_repos/
    ├── rpm_packages/              # vars-only role
    ├── third_party_rpms/          # vivaldi
    ├── appimages/                 # cursor
    ├── profile_d/
    ├── flatpaks/
    ├── systemd_user/              # system side: unit files + user-preset
    ├── services/                  # docker, containerd, podman.socket
    ├── containers_policy/
    ├── fonts/
    └── distrobox/                 # user side
```

There is no inventory file. Each playbook targets `hosts: localhost` with `connection: local`, gathers facts in an unprivileged first play, and a `pre_tasks` block in the second play loads `host_vars/{{ ansible_hostname }}.yml` via `include_vars` if present. This keeps the entrypoint minimal — `sudo -v && ansible-pull -U <repo> system.yml` — without `--limit`, hostname-to-inventory-key matching, or sudo wrapping the whole run.

## Roles

### `bootc_image` (system)

The hard part. Generates a Containerfile from a Jinja template and rebuilds + switches the local derived image when inputs change.

**Inputs (variables):**

- `ars_base_image` — default `ghcr.io/zirconium-dev/zirconium:latest`
- `ars_local_image_tag` — default `localhost/ars-linux:latest`
- `ars_rpm_packages_base` + `ars_rpm_packages_extra` — unioned package list
- `ars_dnf_repo_files` — paths to `.repo` files staged by `dnf_repos`
- `ars_third_party_rpms` — list of `{name, url, sha256, post_install}`
- `ars_appimages` — list of `{name, url, sha256, desktop_exec_override}`
- `ars_zdots_repo` — default `https://github.com/pbonh/zdots.git`
- `ars_zdots_branch` — default `main`
- `ars_containerfile_extra_lines` — escape hatch for ad-hoc `RUN`/`COPY`
- `ars_npm_globals` — list of `{name, version}` packages installed via `npm install -g` in the Containerfile (default: `[{name: openai-codex, version: latest}]`)

**Tasks, in order:**

1. Stage build context at `/var/lib/ars-linux/build/`:
   - Render `Containerfile` from template.
   - Copy in `.repo` files from `dnf_repos`.
   - Stage cosign keys (preserves upstream trust).
   - Stage `relocate-opt.sh` for the `/opt → /usr/lib` brave/vivaldi/cursor relocation.
2. Compute build fingerprint: SHA-256 of rendered Containerfile + checksums of all staged inputs + canonicalized package list. Persist to `/var/lib/ars-linux/last-build.fingerprint`.
3. Skip-or-build: if fingerprint matches and `localhost/ars-linux:latest` already exists in containers-storage, skip the build.
4. Build: `podman build --pull=newer -t {{ ars_local_image_tag }} /var/lib/ars-linux/build/`.
5. Compare booted-deployment digest (from `bootc status --json`) to the just-built image's digest. If different, `bootc switch --transport containers-storage {{ ars_local_image_tag }}`.
6. Notify a `reboot required` handler if the switch happened.
7. Periodic `podman image prune -f` to keep `/var` from filling.

**Containerfile template (sketch):**

```dockerfile
FROM {{ ars_base_image }}

# DNF repos (brave, docker-ce, COPR/atim/starship, COPR/scottames/ghostty,
#            COPR/wezfurlong/wezterm-nightly)
COPY repos/*.repo /etc/yum.repos.d/

# Layered RPMs (base + host extras + third-party repos)
RUN dnf -y install {{ all_packages | join(' ') }} \
 && dnf clean all

# Third-party RPMs (vivaldi)
{% for rpm in ars_third_party_rpms %}
RUN curl -fsSL -o /tmp/{{ rpm.name }}.rpm {{ rpm.url }} \
 && echo "{{ rpm.sha256 }}  /tmp/{{ rpm.name }}.rpm" | sha256sum -c - \
 && dnf -y install /tmp/{{ rpm.name }}.rpm \
 && rm /tmp/{{ rpm.name }}.rpm
{% endfor %}

# /opt → /usr/lib relocation (brave, vivaldi, cursor)
COPY relocate-opt.sh /tmp/
RUN /tmp/relocate-opt.sh && rm /tmp/relocate-opt.sh

# AppImages (cursor)
{% for ai in ars_appimages %}
RUN install -d /usr/lib/{{ ai.name }} \
 && curl -fsSL -o /usr/lib/{{ ai.name }}/{{ ai.name | capitalize }}.AppImage {{ ai.url }} \
 && echo "{{ ai.sha256 }}  /usr/lib/{{ ai.name }}/{{ ai.name | capitalize }}.AppImage" \
    | sha256sum -c - \
 && chmod 0755 /usr/lib/{{ ai.name }}/{{ ai.name | capitalize }}.AppImage
COPY {{ ai.name }}-extract.sh /tmp/
RUN /tmp/{{ ai.name }}-extract.sh && rm /tmp/{{ ai.name }}-extract.sh
{% endfor %}

# pbonh/zdots — mirrors upstream Zirconium install path so dot_config/* works as-is
RUN git clone --depth 1 --branch {{ ars_zdots_branch }} \
      {{ ars_zdots_repo }} /usr/share/zirconium/zdots \
 && rm -rf /usr/share/zirconium/zdots/.git

# npm globals (codex, etc.) — npm comes from the layered package list above
{% for npm in ars_npm_globals %}
RUN NPM_CONFIG_PREFIX=/usr npm install -g {{ npm.name }}@{{ npm.version }}
{% endfor %}

# /var/opt symlinks for immutable app payloads (matches existing fork behavior)
COPY tmpfiles/zirconium-opt.conf /usr/lib/tmpfiles.d/

# Ensure boot-image is well-formed
RUN bootc container lint
```

**Risks named:**

- `bootc switch --transport containers-storage` requires bootc 1.1+; preflight check fails the role early if absent.
- The build runs as root (under `ansible-pull`). The resulting image is read by bootc from root's containers-storage, which is the expected location.
- Local image disk usage grows with every rebuild; `podman image prune -f` runs at end-of-role.

### `dnf_repos` (system)

Renders `.repo` files into `/etc/yum.repos.d/` from templates so live `dnf` (used inside the Containerfile build, plus rare on-host `dnf info` queries) sees them. Repos:

- `brave-browser.repo`
- `docker-ce.repo`
- `_copr:copr.fedorainfracloud.org:atim:starship.repo`
- `_copr:copr.fedorainfracloud.org:scottames:ghostty.repo`
- `_copr:copr.fedorainfracloud.org:wezfurlong:wezterm-nightly.repo`

Files are staged into the `bootc_image` build context as well.

### `rpm_packages` (vars-only)

No tasks. `defaults/main.yml` exposes:

```yaml
ars_rpm_packages_base:
  # Development
  - glibc-devel
  - libstdc++-devel
  - gcc-g++
  - make
  # Editors and terminals
  - kitty
  - neovim
  - ghostty           # COPR
  - wezterm           # COPR
  # CLI tools
  - ansible
  - chezmoi
  - fd-find
  - ripgrep
  - starship          # COPR
  - zsh
  # Containers / VMs
  - distrobox
  - fuse
  - fuse3
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin
  # Browsers
  - brave-browser
  # Desktop apps
  - libreoffice
  - thunderbird
  # Science
  - octave
  # Codex runtime
  - nodejs
  - npm

ars_rpm_packages_extra: []   # appended per-host
```

`bootc_image` consumes the union.

### `third_party_rpms` (system)

List of RPMs installed inside the Containerfile (not on the live host). Initially Vivaldi only — ProtonMail moves to distrobox per the brief.

```yaml
ars_vivaldi_version: "7.x.x.x-1"   # bumped manually; new sha256 must be set with it
ars_third_party_rpms:
  - name: vivaldi-stable
    url: "https://downloads.vivaldi.com/stable/vivaldi-stable-{{ ars_vivaldi_version }}.x86_64.rpm"
    sha256: "TO-BE-PINNED-AT-IMPLEMENTATION"
    post_install: relocate_opt
```

Pinned URL+sha256 pairs are filled in at implementation time, then bumped in lockstep when upstream releases. A `just bump-vivaldi` helper computes the latest version + sha256 and edits this block.

`relocate_opt` is a marker referenced by `relocate-opt.sh` to handle the `/opt/vivaldi → /usr/lib/vivaldi` move and desktop-file `Exec=` rewrite.

### `appimages` (system)

Cursor-only initially. The Containerfile fragment downloads the AppImage to `/usr/lib/cursor/`, runs `--appimage-extract` to grab the `.desktop` file and icons, fixes the `Exec=` line to `/usr/lib/cursor/cursor`, drops a wrapper script in `/usr/lib/cursor/cursor`, and symlinks `/usr/bin/cursor`. SHA-256 checksum verified before extraction.

### `profile_d` (system)

Renders `/etc/profile.d/*.sh` snippets for shell-tool init, each gated on a per-tool boolean:

| File | Gating var |
|---|---|
| `atuin.sh` | `ars_profile_d.atuin` |
| `blesh.sh` | `ars_profile_d.blesh` |
| `brew.sh` | `ars_profile_d.brew` |
| `carapace.sh` | `ars_profile_d.carapace` |
| `fzf.sh` | `ars_profile_d.fzf` |
| `mise.sh` | `ars_profile_d.mise` |
| `starship.sh` | `ars_profile_d.starship` |
| `zoxide.sh` | `ars_profile_d.zoxide` |

Defaults: all `true`. Source content matches the existing snippets in the fork.

### `flatpaks` (system)

Writes `/usr/share/flatpak/preinstall.d/apps.preinstall` from a Jinja template, list driven by `ars_flatpak_preinstalls` (default: 13 apps from current fork — Bitwarden, Kontainer, BoxBuddy, Collabora Office, Alpaca, Obsidian, Cantor, KAlgebra, Qalculate, Ptyxis, Plasmatube, SyncThingy). Also drops `flathub.flatpakrepo` into `/usr/share/flatpak/remotes.d/` so the preinstall mechanism has a remote to pull from.

### `systemd_user` (system side)

Drops, into `/usr/lib/systemd/user/` (image-shipped, like upstream — not `/etc/systemd/user/`):

- `chezmoi-init.service` — first-login oneshot, gated on `ConditionPathExists=!%h/.config/zirconium/chezmoi`. Runs `chezmoi apply -S /usr/share/zirconium/zdots --config %h/.config/zirconium/chezmoi/chezmoi.toml`. Wanted by `graphical-session-pre.target`.
- `chezmoi-update.service` — periodic re-apply. Same `chezmoi apply -S /usr/share/zirconium/zdots ...` invocation, with `yes s | ... --no-tty --keep-going`.
- `chezmoi-update.timer` — fires `chezmoi-update.service` on a default `OnUnitActiveSec=24h` schedule (override per-host via `ars_chezmoi_update_interval`).
- `tailscale-systray.service` — autostart for the Tailscale tray.

Drops a user-preset at `/usr/lib/systemd/user-preset/01-ars-linux.preset`:

```
enable chezmoi-init.service
enable chezmoi-update.timer
enable tailscale-systray.service
```

Presets are the canonical systemd mechanism for "enable these for every user on first login," and are what upstream Zirconium uses (`01-zirconium.preset`). This **replaces** the existing fork's `/etc/systemd/user/default.target.wants/*` symlinks, which bypass per-user enablement.

### `services` (system)

```yaml
- systemctl enable docker.service
- systemctl enable containerd.service
- systemctl enable podman.socket
```

Idempotent. `docker` group is already created by upstream Zirconium's sysusers (preserved unchanged in the derived image's `/usr/lib/sysusers.d/`).

### `containers_policy` (system)

Drops `/etc/containers/policy.json` and `/etc/containers/registries.d/*.yaml` to preserve cosign verification of upstream Zirconium's image registry. Installs cosign public keys to `/etc/pki/containers/`. Files mirror the existing fork's contents in `mkosi.extra/usr/share/factory/etc/containers/`.

### `fonts` (system)

Reserved for future additions. The role exposes `ars_extra_fonts` (default `[]`) which `bootc_image` appends to the Containerfile package list, followed by `fc-cache --force --really-force --system-only`. Empty initially because upstream Zirconium already ships the desired font set; the role exists so that adding a font in the future is one host_var entry, not a Containerfile edit.

### `distrobox` (user side)

The only role with non-trivial logic in `user.yml`. Manages user-owned distrobox containers — currently just ProtonMail.

```yaml
ars_distrobox_containers:
  - name: protonmail
    image: registry.fedoraproject.org/fedora-toolbox:44   # matches Zirconium's Fedora release
    rpms:
      - name: protonmail-desktop-beta
        url: "{{ ars_protonmail_rpm_url }}"   # full URL to be pinned; updated when Proton bumps the beta
        sha256: "TO-BE-PINNED-AT-IMPLEMENTATION"
    exports:
      - app: proton-mail        # `distrobox-export --app`
```

Tasks:

1. `distrobox list` — check if `protonmail` exists.
2. Read marker file `~/.local/state/ars-linux/distrobox/protonmail.sha256`. If it equals the desired RPM sha256 and the container exists, skip.
3. Otherwise: `distrobox create --image registry.fedoraproject.org/fedora-toolbox:44 --name protonmail --yes` (recreate if container existed but RPM hash drifted).
4. `distrobox enter protonmail -- bash -c '...'` to download the RPM, verify sha256, `dnf install -y`, write the marker file.
5. `distrobox-export --app proton-mail` — drops `proton-mail.desktop` into `~/.local/share/applications/` so niri/DankMaterialShell sees it as a normal app.
6. `update-desktop-database ~/.local/share/applications/`.

The `fedora-toolbox:44` choice matches the Fedora release zirconium tracks (per `mkosi.keys/RPM-GPG-KEY-fedora-44-primary` upstream); per-host override available via `host_vars` for hosts on rawhide.

## Multi-host configuration model

`ansible-pull` runs locally with `hosts: localhost`. The first play (no `become`) gathers facts; the second play stats `host_vars/{{ ansible_hostname }}.yml` and loads it via `include_vars` when present, then runs all roles under `become: true`. No SSH, no inventory file, no central control node.

`group_vars/all.yml`:

```yaml
ars_user: phillip
ars_base_image: ghcr.io/zirconium-dev/zirconium:latest
ars_local_image_tag: localhost/ars-linux:latest
ars_zdots_repo: https://github.com/pbonh/zdots.git
ars_zdots_branch: main
ars_rpm_packages_extra: []
ars_flatpak_preinstalls: [...]
ars_systemd_user_units: [tailscale-systray]
ars_profile_d:
  atuin: true
  blesh: true
  brew: true
  carapace: true
  fzf: true
  mise: true
  starship: true
  zoxide: true
```

Per-host examples:

```yaml
# host_vars/laptop.yml
ars_rpm_packages_extra:
  - powertop
  - tlp

# host_vars/workstation.yml
# (defaults only)

# host_vars/nvidia-box.yml
ars_base_image: ghcr.io/zirconium-dev/zirconium-nvidia:latest
ars_rpm_packages_extra:
  - nvidia-container-toolkit
```

Per-host vars are picked up automatically by hostname — set the system hostname (`sudo hostnamectl set-hostname <name>`) and add `host_vars/<name>.yml` to the repo. If the file is absent, the host inherits `group_vars/all.yml` defaults.

Roles register tags matching their names so subsets can be applied:

```bash
sudo -v && ansible-pull -U ... system.yml --tags flatpaks,profile_d
```

## User workflow

```bash
# Authenticate sudo once; ansible uses the cached credentials non-interactively
sudo -v

# Apply system changes (rebuilds + bootc switch when inputs change)
ansible-pull -U https://github.com/pbonh/ars-linux.git system.yml

# Apply user changes
ansible-pull -U https://github.com/pbonh/ars-linux.git user.yml

# Reboot if system.yml triggered an image switch
sudo systemctl reboot
```

`ansible.cfg` sets `become_flags = -n`, so ansible escalates via `sudo -n <cmd>` and never tries to drive the password prompt itself. This sidesteps the well-known "timed out waiting for become success or become password prompt" failure on systems where the first sudo invocation is slow (PAM startup, sssd lookups) or where the prompt string doesn't match ansible's detection regex. The trade-off: the user must `sudo -v` (or run a `just` target that does it) before the playbook starts.

`Justfile` aliases handle the dance — `sudo -v` plus a backgrounded keep-alive loop that refreshes the timestamp every 60s for the duration of the run, since cold first builds can exceed sudo's default 5-minute timestamp_timeout:

```makefile
_sudo-keepalive:
    @sudo -v
    @( while true; do sudo -n true; sleep 60; kill -0 "$(echo $$)" 2>/dev/null || exit; done ) &

sync: _sudo-keepalive
    ansible-pull -U {{repo}} system.yml

sync-user:
    ansible-pull -U {{repo}} user.yml

sync-flatpaks: _sudo-keepalive
    ansible-pull -U {{repo}} system.yml --tags flatpaks

vm-test BRANCH=`main`:
    # spin up a quickemu VM from upstream Zirconium ISO, ansible-pull --branch={{BRANCH}}
```

## Testing & verification

1. **Lint** — `ansible-lint roles/ system.yml user.yml` and `yamllint .` in CI on every push.
2. **Containerfile dry-run** — CI job renders the Containerfile from defaults and runs `bootc container lint` in a privileged container. Catches obvious breakage without booting a VM.
3. **VM smoke test** — manual, via `just vm-test`. Boots a Zirconium ISO in `quickemu`/`virt-install`, runs `ansible-pull` against the WIP branch, verifies boot succeeds and `proton-mail` launches.
4. **Idempotency check** — CI runs the playbook twice in a row in a Fedora container; second run must report zero changes.
5. **Rollback path** — `bootc rollback` always works because each `bootc switch` creates a new deployment. The `bootc_image` role keeps the previous local tag as `localhost/ars-linux:previous` for one-command manual rollback without rebuilding.

## Migration mapping (fork → ars-linux)

| Fork artifact | ars-linux destination |
|---|---|
| `mkosi.conf.d/pbonh-brave.conf` | `dnf_repos` (brave-browser.repo) + `rpm_packages` (brave-browser) |
| `mkosi.conf.d/pbonh-copr.conf` | `dnf_repos` (3 COPR .repo files) + `rpm_packages` (starship/ghostty/wezterm) |
| `mkosi.conf.d/pbonh-docker.conf` | `dnf_repos` (docker-ce.repo) + `rpm_packages` (docker-ce et al.) + `services` |
| `mkosi.conf.d/pbonh-extras.conf` | `rpm_packages` (kitty, neovim, ansible, ...) |
| `mkosi.extra/usr/lib/systemd/user/tailscale-systray.service` | `systemd_user` |
| `mkosi.extra/usr/lib/sysusers.d/docker.conf` | inherited from upstream Zirconium (no change needed) |
| `mkosi.extra/usr/lib/tmpfiles.d/zirconium-opt.conf` | `bootc_image` (Containerfile COPY) |
| `mkosi.extra/usr/share/factory/etc/profile.d/*.sh` | `profile_d` |
| `mkosi.extra/usr/share/factory/etc/containers/*` | `containers_policy` |
| `mkosi.extra/usr/share/flatpak/preinstall.d/apps.preinstall` | `flatpaks` |
| `mkosi.extra/usr/share/zirconium/zdots` (submodule) | `bootc_image` clones `pbonh/zdots` to `/usr/share/zirconium/zdots/` + `systemd_user` chezmoi services |
| `mkosi.postinst.chroot` brave/vivaldi/cursor relocation | `bootc_image` `relocate-opt.sh` invoked from Containerfile |
| `mkosi.postinst.chroot` ProtonMail RPM install | `distrobox` (user side) |
| `mkosi.postinst.chroot` Codex npm install | `bootc_image` Containerfile (`npm install -g openai-codex`) |
| `mkosi.postinst.chroot` service enables | `services` |
| `iso.toml`, `iso-nvidia.toml`, GH Actions workflows | not migrated (out of scope) |
