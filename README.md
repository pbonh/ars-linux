# zinstall

Bring a freshly installed [Zirconium](https://github.com/zirconium-dev/zirconium)
box (Fedora bootc + Niri) to a fully personalized state in one command, and
re-converge that state on every subsequent run.

## Prerequisite: enable rpm-ostree layering

Stock Zirconium ships with `LockLayering=true` in `/etc/rpm-ostreed.conf`.
That setting blocks `rpm-ostree install` / `uninstall`, which Phase 6 (`layered`)
needs in order to install OS-level packages such as `docker-ce`. Run this once
on a new host before invoking `install.sh`:

```bash
sudo sed -i 's/^LockLayering=true/LockLayering=false/' /etc/rpm-ostreed.conf
sudo systemctl restart rpm-ostreed
```

Verify:

```bash
grep LockLayering /etc/rpm-ostreed.conf   # → LockLayering=false
rpm-ostree status                          # should still show your deployment
```

The change persists in `/etc/`, so it survives `bootc upgrade` unless an
upstream image ships a different `rpm-ostreed.conf`. If a future upgrade
re-locks layering, re-run the two commands above. zinstall will detect the
locked state and abort Phase 6 with a pointer back to this section rather
than silently skipping declared packages.

> Why not auto-disable it from `install.sh`? Modifying a system policy file
> is something you should do deliberately, with eyes open. Two commands once
> is a fair trade for that clarity.

## Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/pbonh/ars-linux/main/install.sh | bash
```

For re-runs: `git clone` and invoke `./install.sh` directly.

## Flags

```
--upgrade              Upgrade brew bundle, chezmoi, and the bootc image.
--dry-run              Print every state-changing command, do not execute.
--no-reboot-prompt     Suppress the reboot question.
--prune                Remove items no longer declared in package files.
--only=<phase[,...]>   Run only listed phases.
--skip=<phase[,...]>   Skip listed phases.
-v, --verbose          Show every command before running it.
-h, --help             Print usage.
```

Phases: `brew`, `chezmoi`, `brewfile`, `distrobox`, `autostart`, `layered`,
`postinstall`, `system`.

## Customization layers

1. `packages/Brewfile` — Homebrew formulae and Flatpaks.
2. `packages/distroboxes.ini` — Distrobox containers.
3. `packages/autostart.list` — systemd --user autostart units (`zinstall-*`).
4. `packages/layered.txt` and `packages/repos/*.repo` — rpm-ostree layering.
5. `packages/post-install.d/*.sh` — idempotent post-layering hooks.

Dotfiles live in [`pbonh/zdots`](https://github.com/pbonh/zdots) and are
materialized by chezmoi.

## Tests

```bash
bats tests/
```
