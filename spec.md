# zinstall — Spec (rev 2)

**Repo:** `github.com/pbonh/zinstall`
**Target system:** Zirconium (Fedora bootc + Niri)
**Language:** Bash (5+), POSIX-leaning where painless

## 1. Goal

Bring a freshly installed Zirconium system to a fully personalized state with one curl-piped command, and bring it back to that state on every subsequent run. No forking the upstream image. Customization happens entirely in layers above the bootc image:

1. A unified **Brewfile** for CLI tooling (Homebrew formulae) and GUI apps (Flatpaks via the new `flatpak` directive).
2. **Distrobox** containers, with binaries/apps exported to the host.
3. **systemd user units** for autostart, replacing any DE-specific autostart mechanism.
4. **chezmoi** pulling dotfiles from `github.com/pbonh/zdots`.
5. A short, well-justified list of **rpm-ostree layered packages** for things that genuinely belong at the OS layer.

## 2. Non-goals

- Not a fork or derivative image. If a customization needs to live in `/usr`, that's a signal it should move to a BlueBuild recipe instead.
- Not a general-purpose distro installer. Assumes Zirconium is already booted.
- Not a secrets manager. chezmoi handles dotfile templating; secrets are out of scope.
- No `uninstall.sh` for now.

## 3. Bootstrap

A single command on a fresh Zirconium box:

```bash
curl -fsSL https://raw.githubusercontent.com/pbonh/zinstall/main/install.sh | bash
```

For re-runs and upgrades, the user clones the repo and invokes `./install.sh` directly with flags.

## 4. Repository layout

```
zinstall/
├── install.sh              # Main entry point
├── lib/
│   ├── log.sh              # Logging primitives
│   ├── preflight.sh        # System checks
│   ├── brew.sh             # Homebrew + Brewfile phase
│   ├── chezmoi.sh          # chezmoi phase
│   ├── distrobox.sh        # Distrobox phase (incl. export)
│   ├── autostart.sh        # systemd --user unit generation
│   ├── layered.sh          # rpm-ostree phase
│   └── system.sh           # bootc system upgrade
├── packages/
│   ├── Brewfile            # Brew formulae, taps, Flatpaks
│   ├── distroboxes.ini     # distrobox-assemble format
│   ├── autostart.list      # Commands to autostart via systemd --user
│   └── layered.txt         # One rpm-ostree package per line
├── .github/workflows/
│   └── dry-run.yml         # CI: --dry-run inside Zirconium container
├── README.md
└── LICENSE
```

Each `lib/*.sh` module exports a single `run_<phase>` function and is sourced by `install.sh`.

## 5. Execution phases

`install.sh` runs phases in this fixed order. Each phase is independently idempotent and skippable.

### Phase 0 — Preflight (`lib/preflight.sh`)
- Verify the host is bootc-based: `command -v bootc && bootc status` succeeds.
- Verify Fedora-family: `/etc/os-release` contains `ID=fedora` or `ID_LIKE=*fedora*`.
- Verify network connectivity: HEAD against `https://github.com`.
- Verify `sudo` is available and prime the timestamp (`sudo -v`); start a background keep-alive loop that dies with the script.
- Refuse to run as root.

### Phase 1 — Homebrew (`lib/brew.sh`)
- **Install if missing:** detect `command -v brew || [ -x /home/linuxbrew/.linuxbrew/bin/brew ]`. If absent, run the official installer non-interactively (`NONINTERACTIVE=1`).
- **Shell env:** evaluate `brew shellenv` for the current process. Permanent shell integration is owned by the chezmoi-managed dotfiles; the script never writes to `~/.bashrc` or `~/.zshrc`.

### Phase 2 — chezmoi (`lib/chezmoi.sh`)
- If `chezmoi` is not on PATH, `brew install chezmoi`.
- If `~/.local/share/chezmoi` doesn't exist or isn't a git repo, run `chezmoi init --apply pbonh/zdots`.
- Otherwise, run `chezmoi apply` to enforce state.
- **Upgrade (when `--upgrade`):** `chezmoi update` (which does pull + apply).

### Phase 3 — Brewfile (`lib/brew.sh`, second pass)
- Single source of truth for both Homebrew and Flatpak: `packages/Brewfile`.
- Confirm `brew bundle` recognizes the `flatpak` directive (`brew bundle --help | grep -q flatpak`); if not, fail with a message asking the user to update Homebrew.
- Run `brew bundle install --file=packages/Brewfile`. This is natively idempotent.
- **Upgrade (when `--upgrade`):** the same command (default behavior is to upgrade); without `--upgrade`, set `HOMEBREW_BUNDLE_NO_UPGRADE=1` for the call.
- **Prune (when `--prune`):** `brew bundle cleanup --file=packages/Brewfile --force` removes anything not in the Brewfile (formulae *and* Flatpaks).

Sample `Brewfile`:
```ruby
# CLI essentials
brew "git"
brew "gh"
brew "fzf"
brew "ripgrep"
brew "just"
brew "chezmoi"

# Taps
tap "homebrew/bundle"

# Flatpaks (from default Flathub remote)
flatpak "com.github.tchx84.Flatseal"
flatpak "org.mozilla.firefox"
flatpak "md.obsidian.Obsidian"

# Flatpak from a non-default remote
# flatpak "org.godotengine.Godot", remote: "flathub-beta", url: "https://dl.flathub.org/beta-repo/"
```

### Phase 4 — Distrobox (`lib/distrobox.sh`)
- `distrobox` is expected to be present on Zirconium. If missing, fail with a clear message.
- Read `packages/distroboxes.ini` in the format `distrobox-assemble` accepts natively, including its built-in `exported_apps` and `exported_bins` fields:

  ```ini
  [dev]
  image=registry.fedoraproject.org/fedora-toolbox:41
  init=true
  start_now=true
  additional_packages="git gcc make"
  exported_bins="/usr/bin/podman /usr/bin/cargo"
  exported_apps="code"
  ```
- For each `[name]` section, check `distrobox list` for the name. If absent, run `distrobox-assemble create --file packages/distroboxes.ini --name <name>` — assemble handles the export step itself when `exported_*` fields are set.
- For existing containers, do not recreate (assemble is finicky about that). Re-run `distrobox-export` directly per declared binary/app to enforce export idempotently.

### Phase 5 — Autostart (`lib/autostart.sh`)
- Goal: launch user-session applications without depending on Niri's `spawn-at-startup`, GNOME's autostart, KDE's, or XDG `~/.config/autostart/`. Everything goes through `systemd --user`.
- Read `packages/autostart.list`. One unit per line. Two supported formats:

  ```
  # Bare command — service name is auto-generated from the basename of the executable
  flatpak run com.github.tchx84.Flatseal

  # Named: <slug>=<command>
  music=flatpak run com.spotify.Client
  ```
- Generate a `~/.config/systemd/user/zinstall-<slug>.service` unit per entry:

  ```ini
  [Unit]
  Description=zinstall-managed autostart: <slug>
  After=graphical-session.target
  PartOf=graphical-session.target

  [Service]
  Type=simple
  ExecStart=<command>
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=graphical-session.target
  ```
- After writing, `systemctl --user daemon-reload` then `systemctl --user enable --now zinstall-<slug>.service` for each.
- **Idempotency:** rewrite a unit only if its content actually changed (compare hashes). Skip `enable --now` if already active.
- **Pruning (when `--prune`):** any `~/.config/systemd/user/zinstall-*.service` not in the current list is disabled, stopped, and removed.
- All managed units are namespaced with the `zinstall-` prefix so the script never touches user-authored units.

### Phase 6 — rpm-ostree layered packages (`lib/layered.sh`)
- Read `packages/layered.txt`.
- Get the current layered set: `rpm-ostree status --json | jq -r '.deployments[0]["requested-packages"][]'`.
- Compute the diff. If non-empty, run `sudo rpm-ostree install --idempotent --allow-inactive <pkgs...>` in one call.
- Compute removals: packages currently layered but no longer in `layered.txt` → `sudo rpm-ostree uninstall <pkgs...>`. Gated behind `--prune`.
- Set the global flag `REBOOT_NEEDED=1` if any layering change occurred.

### Phase 7 — System upgrade (`lib/system.sh`, only when `--upgrade`)
- `sudo bootc upgrade` to pull the latest Zirconium image. This stages a new deployment.
- If `bootc upgrade` reports a new deployment was staged, set `REBOOT_NEEDED=1`.
- This phase is **only** run with `--upgrade`. Without the flag, leave the system image alone.

### Phase 8 — Summary & reboot
- Print a summary table: per-phase counts of installed/upgraded/skipped/failed.
- If `REBOOT_NEEDED=1` and stdin is a TTY and `--no-reboot-prompt` is not set, prompt: `Reboot now? [y/N]`. On `y`, `systemctl reboot`. Otherwise print a clear reminder.
- Exit non-zero if any phase failed.

## 6. File formats

### `Brewfile`
Standard Homebrew Bundle syntax. Supports `brew`, `tap`, `cask` (no-op on Linux), `vscode`, and `flatpak`. Comments use `#`. See sample in §5 Phase 3.

### `distroboxes.ini`
Standard `distrobox-assemble` INI format. Each `[section]` is a container name. Supported keys include `image`, `init`, `start_now`, `additional_packages`, `exported_bins`, `exported_apps`, `nvidia`, `pull`, `root`. Refer to upstream distrobox docs for the full set.

### `autostart.list`
UTF-8. `#` line comments. Blank lines ignored. Each non-empty line is either a bare command (slug derived from the executable basename) or `<slug>=<command>`. Slugs must match `[a-z0-9-]+`.

### `layered.txt`
UTF-8. `#` line comments. One package name per line. Trailing whitespace trimmed. Order does not matter.

```
# Keep this list short. Every entry adds boot time and rebase risk.
# Prefer Homebrew or Flatpak whenever possible.
zsh
```

## 7. Idempotency contract

Every phase, run twice in a row with no underlying change, must produce zero state changes on the second run.

| Phase | Idempotency mechanism |
| --- | --- |
| Homebrew install | `command -v brew` guard |
| chezmoi init | Check for `~/.local/share/chezmoi/.git` |
| chezmoi apply | Native chezmoi behavior |
| Brewfile | Native `brew bundle install` semantics (formulae + Flatpaks) |
| distroboxes | Diff against `distrobox list` per name; export step re-run safely |
| autostart | Hash compare per unit; `enable --now` is a no-op if already enabled & active |
| layered | Diff against `rpm-ostree status --json` requested-packages |
| system upgrade | Native `bootc upgrade` semantics — stages only if newer image exists |

The script must **never** call a destructive command unconditionally.

## 8. CLI flags

```
install.sh [flags]

  --upgrade              Run brew bundle upgrade, chezmoi update, and bootc upgrade.
  --dry-run              Print every state-changing command, do not execute.
  --no-reboot-prompt     Suppress the reboot question; just report.
  --prune                Remove items no longer declared:
                           - layered packages no longer in layered.txt
                           - systemd autostart units no longer in autostart.list
                           - Brewfile entries via `brew bundle cleanup`
  --only=<phase[,...]>   Run only listed phases. Names: brew, chezmoi, brewfile,
                         distrobox, autostart, layered, system.
  --skip=<phase[,...]>   Skip listed phases.
  -v, --verbose          Show every command before running it (set -x).
  -h, --help             Print usage and exit 0.
```

`--only` and `--skip` are mutually exclusive. Unknown phase names are an error.

## 9. Error handling

- `set -Eeuo pipefail` at the top of `install.sh`.
- A `trap '... ERR'` handler that prints the failed command, file, and line.
- Each phase wraps its body so a phase failure is logged but does not abort the script — the run continues to subsequent phases. The final exit code is non-zero if any phase failed.
- Network-dependent steps retry with exponential backoff up to 3 attempts.
- `--dry-run` must short-circuit every state-changing call but still exercise the same control flow.

## 10. Logging

- All output goes through `lib/log.sh`, which provides `log::info`, `log::warn`, `log::error`, `log::ok`, `log::section`.
- ANSI color when stdout is a TTY and `NO_COLOR` is unset.
- Every run also tees a plain-text copy to `~/.cache/zinstall/run-$(date +%Y%m%dT%H%M%S).log`. Logs older than 30 days pruned at the start of each run.

## 11. Interaction with chezmoi-managed dotfiles

- The script does not write to `~/.bashrc`, `~/.zshrc`, `~/.profile`, or any other shell rc file. Shell setup lives in zdots.
- The script does not place anything in `~/.config/niri/`. All Niri config is chezmoi-managed.
- The script *does* write to `~/.config/systemd/user/`, but only files matching `zinstall-*.service`. zdots is free to drop other unit files there.
- After Phase 2, zdots is on disk; the canonical source for `packages/*` remains the zinstall repo.

## 12. CI

GitHub Actions workflow at `.github/workflows/dry-run.yml`:
- Runs on every push and PR.
- Job: pulls the latest Zirconium image (`ghcr.io/zirconium-dev/zirconium:latest`) as a container and executes `./install.sh --dry-run --no-reboot-prompt` inside it.
- Validates that all phases reach completion in dry-run mode and that `Brewfile` parses (`brew bundle check --file=packages/Brewfile`).
- Caches `/home/linuxbrew/.linuxbrew` between runs.

## 13. Open questions (deferred)

None outstanding from the previous round. Future items will be tracked as GitHub issues.
