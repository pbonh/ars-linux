# ars-linux

Ansible-driven customization layer for [Zirconium](https://github.com/zirconium-dev/zirconium).

Builds a local-only derived OCI image on top of the unmodified upstream image and
activates it with `bootc switch`. See
[design spec](docs/superpowers/specs/2026-04-27-ars-linux-design.md) for the full rationale.

## Inventory

`ansible-pull` reads `inventory/hosts` to resolve `inventory_hostname` against
`host_vars/<hostname>.yml`. Each host runs locally; there is no central control
node and no SSH:

```ini
# inventory/hosts
[all]
laptop      ansible_connection=local
workstation ansible_connection=local
nvidia-box  ansible_connection=local
```

To add a new host:

1. Add it to `inventory/hosts` with `ansible_connection=local`.
2. Set the system's hostname to match (`sudo hostnamectl set-hostname <name>`).
3. Create `host_vars/<name>.yml` with any per-host overrides (or leave empty to
   inherit `group_vars/all.yml` defaults). See `host_vars/laptop.yml` and
   `host_vars/nvidia-box.yml` for examples.

## Usage

```bash
# Apply system changes (rebuilds + bootc switch when inputs change)
sudo ansible-pull -U https://github.com/pbonh/ars-linux.git -i inventory/hosts system.yml

# Apply user changes
ansible-pull -U https://github.com/pbonh/ars-linux.git -i inventory/hosts user.yml
```

Or: `just sync`, `just sync-user`, `just sync-flatpaks`.

If `system.yml` triggered a `bootc switch`, a marker appears at
`/var/lib/ars-linux/reboot-required`. Reboot to activate the new deployment.

## Development

```bash
pip install -r requirements-dev.txt
yamllint .
ansible-lint roles/ system.yml user.yml
pytest
```
