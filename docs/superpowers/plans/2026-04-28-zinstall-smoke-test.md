# zinstall — Manual Smoke Test (fresh Zirconium VM)

This is a humans-only verification run. CI is not gated on it.

## Procedure

1. Boot a fresh Zirconium VM image (`ghcr.io/zirconium-dev/zirconium:latest`).
2. Log in as the unprivileged user.
3. Bootstrap:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/pbonh/zinstall/main/install.sh | bash
   ```
4. Confirm the run completes; if `REBOOT_NEEDED=1`, accept the prompt or
   `systemctl reboot` manually.
5. After reboot, clone the repo and re-run:
   ```bash
   git clone https://github.com/pbonh/zinstall ~/src/zinstall
   cd ~/src/zinstall
   ./install.sh --no-reboot-prompt
   ```
6. Verify that every phase in the summary reports `ok` and that no items are
   re-installed (idempotency).

## Pass criteria

- [ ] `brew --version` works from a fresh shell.
- [ ] `chezmoi status` is clean.
- [ ] `flatpak list --user` shows Zed, Flatseal, Firefox, Obsidian, Discord.
- [ ] `distrobox list` shows `dev` (running) and `ubuntu` (stopped).
- [ ] `systemctl --user list-unit-files 'zinstall-*.service'` matches
      `packages/autostart.list`.
- [ ] `rpm-ostree status` shows the docker-ce package set layered.
- [ ] `docker run hello-world` succeeds as the user with no sudo.
- [ ] A second `./install.sh --dry-run` produces zero state-changing actions.
