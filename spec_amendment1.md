# zinstall — Spec Amendment 1

**Status:** Update layered on top of `zinstall-spec.md` rev 2. Implementation is in progress; this document is additive and call-out-driven, not a rewrite. Apply each change against rev 2 by section.

**Subject:** Populate the package files with the actual customization set (Zed, Docker, ble.sh, and friends), and add the two small mechanisms required to support them on bootc — extra dnf repos and post-install hooks.

---

## A. Summary of changes

1. **New mechanism:** `packages/repos/*.repo` — additional dnf repository files dropped into `/etc/yum.repos.d/` before Phase 6 (layered).
2. **New phase:** Phase 6.5 — Post-install hooks. Idempotent shell snippets in `packages/post-install.d/*.sh` that run after layered packages and after the user has rebooted into them.
3. **Cross-repo clarification:** ble.sh is **not** managed by zinstall. It belongs in zdots via `.chezmoiexternal.toml`. Reference config provided in §F.
4. **Concrete content** for `Brewfile`, `distroboxes.ini`, `autostart.list`, `layered.txt`, `repos/`, and `post-install.d/`.

---

## B. Repository layout — additions to §4

```
zinstall/
└── packages/
    ├── Brewfile
    ├── distroboxes.ini
    ├── autostart.list
    ├── layered.txt
    ├── repos/                     # NEW — dnf .repo files
    │   └── docker-ce.repo
    └── post-install.d/            # NEW — idempotent post-layering hooks
        ├── 10-docker.sh
        └── 20-flathub.sh
```

A new module `lib/postinstall.sh` is added alongside the existing `lib/*.sh` modules.

---

## C. Phase changes

### C.1 Phase 6 (layered) — prepended sub-step

Before computing the package diff against `rpm-ostree status`, the layered phase must now:

1. Iterate `packages/repos/*.repo`.
2. For each, compare its contents against `/etc/yum.repos.d/<basename>` (hash-compare).
3. If absent or different, `sudo install -m 0644 <src> /etc/yum.repos.d/<basename>`.
4. If any repo file changed, treat that as a state change for purposes of `rpm-ostree`'s next install — no special handling needed; `rpm-ostree install` will pick it up because the repo is present at `/etc/yum.repos.d/` at install time on bootc.

Idempotency: hash-compare guards every copy. No-op when content matches.

### C.2 Phase 6.5 (NEW) — Post-install hooks (`lib/postinstall.sh`)

Inserts between the existing Phase 6 (layered) and Phase 7 (system upgrade).

**Behavior:**
- Iterate `packages/post-install.d/*.sh` in lexicographic order.
- For each, execute under `bash -e -u -o pipefail <script>` with the user's environment.
- Each script is responsible for its own idempotency.
- Script failures are logged via `log::error` but do not abort the run; they contribute to the non-zero final exit code.
- Skipped under `--skip=postinstall` or selected via `--only=postinstall`.

**Phase name for `--only`/`--skip`:** `postinstall`.

**Why a separate phase:** post-install actions like enabling `docker.socket` or `usermod -aG docker $USER` only succeed *after* the user has rebooted into the layered deployment. Running them every invocation, idempotently, naturally handles the "first run installs, second run (post-reboot) configures" flow without state files.

### C.3 §5 phase ordering — updated

```
Phase 0  — Preflight
Phase 1  — Homebrew install
Phase 2  — chezmoi
Phase 3  — Brewfile
Phase 4  — Distrobox
Phase 5  — Autostart units
Phase 6  — Layered packages (now also drops repo files)
Phase 6.5 — Post-install hooks            ← NEW
Phase 7  — System upgrade (--upgrade only)
Phase 8  — Summary & reboot
```

### C.4 §7 idempotency contract — added rows

| Phase | Idempotency mechanism |
| --- | --- |
| repo file drop | Hash-compare per `.repo` file |
| post-install | Each script is required to self-guard |

### C.5 §8 CLI flags — `--only`/`--skip` phase names

Add `postinstall` to the recognized phase names list. Also: the `repos` directory is processed as part of `layered`, not as its own phase.

---

## D. Concrete content

### D.1 `packages/Brewfile`

```ruby
# === CLI essentials ===
brew "git"
brew "gh"
brew "fzf"
brew "ripgrep"
brew "fd"
brew "bat"
brew "eza"
brew "zoxide"
brew "starship"
brew "just"
brew "jq"
brew "yq"
brew "chezmoi"
brew "neovim"
brew "tmux"
brew "lazygit"

# === Dev tooling ===
brew "uv"             # Python package manager
brew "pnpm"           # JS package manager
brew "rustup"         # Rust toolchain manager (use rustup-init on first run)
brew "cmake"
brew "pkgconf"

# === GUI apps via Flatpak ===
flatpak "dev.zed.Zed"                          # Zed editor (Linux native build)
flatpak "com.github.tchx84.Flatseal"           # Flatpak permissions UI
flatpak "org.mozilla.firefox"
flatpak "md.obsidian.Obsidian"
flatpak "com.discordapp.Discord"
```

> **Verify before merge:** `dev.zed.Zed` is the current Flathub app ID for Zed at time of writing. If Zed has shipped a different official Flatpak ID since, swap it in.

### D.2 `packages/distroboxes.ini`

```ini
[dev]
image=registry.fedoraproject.org/fedora-toolbox:41
init=true
start_now=true
additional_packages="git gcc gcc-c++ make cmake pkgconf-pkg-config openssl-devel"
exported_bins="/usr/bin/podman"

[ubuntu]
image=quay.io/toolbx/ubuntu-toolbox:24.04
init=true
start_now=false
additional_packages="git build-essential curl"
```

### D.3 `packages/autostart.list`

```
# Format: <slug>=<command>  OR  bare command
# Slug auto-derived from executable basename if omitted.

# Example: nothing autostarted by default. Uncomment as needed.
# flatseal=flatpak run com.github.tchx84.Flatseal
```

### D.4 `packages/layered.txt`

```
# Keep this list short. Every entry adds boot time and rebase risk.
# Prefer Homebrew or Flatpak whenever possible.

# Real Docker daemon (see post-install.d/10-docker.sh for service+group setup).
# Pulls in the docker-ce repo from packages/repos/docker-ce.repo.
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

> **Conflict note:** `docker-ce` and `moby-engine`/`podman-docker` are mutually exclusive. If either of those gets layered later, `rpm-ostree install` will fail loudly. Podman itself remains installed via Zirconium's base image and is untouched.

### D.5 `packages/repos/docker-ce.repo`

Verbatim from `https://download.docker.com/linux/fedora/docker-ce.repo`. Bundle it in the repo rather than fetching at install time so layering is reproducible offline.

```ini
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
```

### D.6 `packages/post-install.d/10-docker.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Skip if docker isn't installed yet (e.g. layered but reboot hasn't happened).
if ! command -v docker >/dev/null 2>&1; then
  echo "docker not on PATH yet; skipping (reboot pending after rpm-ostree install)"
  exit 0
fi

# Enable socket (idempotent: is-enabled returns 0 if already enabled).
if ! systemctl is-enabled --quiet docker.socket 2>/dev/null; then
  sudo systemctl enable --now docker.socket
fi

# Ensure docker group exists and current user is a member.
if ! getent group docker >/dev/null; then
  sudo groupadd -r docker
fi
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to docker group. Log out and back in (or reboot) to pick up the new group."
fi
```

### D.7 `packages/post-install.d/20-flathub.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Ensure the user-level Flathub remote exists. brew bundle's flatpak directive
# assumes it; this script is a belt-and-suspenders idempotent guard.
if ! flatpak --user remotes --columns=name | grep -qx flathub; then
  flatpak remote-add --user --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
fi
```

---

## E. CI implications

`.github/workflows/dry-run.yml` (from rev 2 §12) now must also:
- Validate that `packages/repos/*.repo` parses as INI (a quick `awk` or `python -c "import configparser; ..."` check).
- `bash -n packages/post-install.d/*.sh` for syntax check.
- Verify ordering convention: post-install snippets are numbered with a 2-digit prefix.

---

## F. Cross-repo: ble.sh belongs in zdots, not zinstall

ble.sh (https://github.com/akinomyoga/ble.sh) is a Bash line editor. It is loaded by sourcing `~/.local/share/blesh/ble.sh` from `.bashrc` — pure dotfile territory. zinstall is the wrong layer.

**Recommended zdots configuration (for reference, not implemented here):**

`zdots/.chezmoiexternal.toml`:
```toml
[".local/share/blesh-src"]
    type = "git-repo"
    url = "https://github.com/akinomyoga/ble.sh.git"
    refreshPeriod = "168h"
    [".local/share/blesh-src".clone]
        args = ["--recursive", "--depth=1", "--shallow-submodules"]
    [".local/share/blesh-src".pull]
        args = ["--ff-only"]
```

`zdots/run_onchange_after_install-blesh.sh.tmpl`:
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
# hash: {{ include ".local/share/blesh-src/make_command.sh" | sha256sum }}
cd "$HOME/.local/share/blesh-src"
make install PREFIX="$HOME/.local"
```

`zdots/dot_bashrc` (relevant fragment):
```bash
# Load ble.sh interactively only.
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach
# ... rest of bashrc ...
[[ ${BLE_VERSION-} ]] && ble-attach
```

zinstall is responsible only for ensuring `make` and `gawk` are present (already covered by the Brewfile-pulled dev tooling and the base Zirconium image).

---

## G. Action items for implementation

1. Add `packages/repos/` and `packages/post-install.d/` to the repo, with the contents in §D.
2. Implement `lib/postinstall.sh` per §C.2.
3. Extend `lib/layered.sh` with the repo-file copy step per §C.1.
4. Update `--only`/`--skip` to recognize `postinstall`.
5. Update CI workflow per §E.
6. File a tracking issue in zdots for the ble.sh setup in §F.
7. Smoke test: fresh Zirconium VM → `curl | bash` → reboot → re-run → confirm `docker run hello-world` works as the user (no sudo).

---

## H. Decisions made unilaterally (flag if you disagree)

- **Zed:** went with the Flathub Flatpak (`dev.zed.Zed`) over a Homebrew install. Flatpak is the more "Zirconium-native" path and avoids the Homebrew Linux GUI-app rough edges.
- **Distrobox set:** included a `dev` (Fedora toolbox) and an `ubuntu` toolbox. The Ubuntu one is `start_now=false` since you'll rarely want both running on boot.
- **Docker-related package set:** included CLI, buildx, and compose plugins alongside `docker-ce`. Drop the plugins from `layered.txt` if you don't want them.
- **Post-install ordering convention:** 2-digit numeric prefix (`10-`, `20-`, ...) for predictable lex ordering. CI enforces it.
