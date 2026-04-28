# ars-linux

Ansible-driven customization layer for [Zirconium](https://github.com/zirconium-dev/zirconium).

Builds a local-only derived OCI image on top of the unmodified upstream image and
activates it with `bootc switch`. See
[design spec](docs/superpowers/specs/2026-04-27-ars-linux-design.md) for the full rationale.

## Usage

On any bootc-enabled host:

```bash
# Apply system changes (rebuilds + bootc switch when inputs change)
sudo ansible-pull -U https://github.com/pbonh/ars-linux.git system.yml

# Apply user changes (run as your normal user, no sudo)
ansible-pull -U https://github.com/pbonh/ars-linux.git user.yml
```

Or: `just sync`, `just sync-user`, `just sync-flatpaks`.

Why `sudo` on `system.yml` and not on `user.yml`: `system.yml` builds the
derived bootc image, drives `bootc switch`, and writes to `/etc` — it is meant
to run as root end-to-end. Running it under `sudo` is the simplest, most
robust pattern for `ansible-pull`. (`-K` / `become_flags=-n` are alternatives,
but both have failure modes — ansible's prompt-detection regex races against
slow PAM startup, and sudo's per-tty credential cache isn't visible to
ansible's worker processes.) `user.yml` only touches per-user state
(distrobox, dotfiles), so it stays unprivileged.

If `system.yml` triggered a `bootc switch`, a marker appears at
`/var/lib/ars-linux/reboot-required`. Reboot to activate the new deployment.

## Per-host configuration

Each playbook gathers facts and, if `host_vars/<ansible_hostname>.yml` exists in
the repo, loads it to override defaults from `group_vars/all.yml`. There is no
inventory file — `ansible-pull` runs locally on a single machine.

To customize a host:

1. Set its hostname (`sudo hostnamectl set-hostname <name>`).
2. Create `host_vars/<name>.yml` with any overrides (or omit the file to inherit
   `group_vars/all.yml` defaults). See `host_vars/laptop.yml` and
   `host_vars/nvidia-box.yml` for examples.

## Development

```bash
pip install -r requirements-dev.txt
yamllint .
ansible-lint roles/ system.yml user.yml
pytest
```
