# ars-linux

Ansible-driven customization layer for [Zirconium](https://github.com/zirconium-dev/zirconium).

Builds a local-only derived OCI image on top of the unmodified upstream image and
activates it with `bootc switch`. See
[design spec](docs/superpowers/specs/2026-04-27-ars-linux-design.md) for the full rationale.

## Usage

On any bootc-enabled host, run as your normal user:

```bash
# Apply system changes (rebuilds + bootc switch when inputs change)
ansible-pull -U https://github.com/pbonh/ars-linux.git -K system.yml

# Apply user changes
ansible-pull -U https://github.com/pbonh/ars-linux.git user.yml
```

`-K` (`--ask-become-pass`) prompts once for your sudo password; tasks that need
root escalate via `become`. The repo clones into `~/.ansible/pull/`. Don't run
either command with `sudo` — `system.yml` does its own escalation, and
`user.yml` is meant to run as the desktop user.

Or: `just sync`, `just sync-user`, `just sync-flatpaks`.

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
