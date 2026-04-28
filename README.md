# ars-linux

Ansible-driven customization layer for [Zirconium](https://github.com/zirconium-dev/zirconium).

Builds a local-only derived OCI image on top of the unmodified upstream image and
activates it with `bootc switch`. See
[design spec](docs/superpowers/specs/2026-04-27-ars-linux-design.md) for the full rationale.

## Usage

The recommended entrypoint is `just`, which authenticates sudo once and keeps
the timestamp cache warm in the background while ansible-pull runs:

```bash
just sync          # apply system changes (rebuilds + bootc switch on change)
just sync-user     # apply user changes
just sync-flatpaks # only refresh flatpaks
```

If you don't want `just`, do the same dance manually:

```bash
sudo -v   # one-time prompt; cached for the run
ansible-pull -U https://github.com/pbonh/ars-linux.git system.yml
ansible-pull -U https://github.com/pbonh/ars-linux.git user.yml
```

`ansible.cfg` sets `become_flags = -n`, so ansible uses sudo's cached
credentials non-interactively — there's no `-K` prompt-detection race during
the run. Don't wrap either invocation with `sudo`; `system.yml` escalates
per-task via `become`, and `user.yml` is meant to run as the desktop user.
The repo clones into `~/.ansible/pull/`.

> **Long runs:** sudo's default credential cache is 5 minutes. `just sync`
> backgrounds a keep-alive that refreshes it every 60s for the duration of the
> run. If you run `ansible-pull` by hand for something that takes longer than
> 5 minutes (e.g., a cold first build), either use `just`, bump
> `Defaults timestamp_timeout` in `/etc/sudoers.d/ars-linux`, or expect to
> re-authenticate mid-run.

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
