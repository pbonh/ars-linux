# ars-linux

Ansible-driven customization layer for [Zirconium](https://github.com/zirconium-dev/zirconium).

Builds a local-only derived OCI image on top of the unmodified upstream image and
activates it with `bootc switch`. See
[design spec](docs/superpowers/specs/2026-04-27-ars-linux-design.md) for the full rationale.

## Usage

```bash
# Apply system changes (rebuilds + bootc switch when inputs change)
sudo ansible-pull -U https://github.com/pbonh/ars-linux.git -i inventory/hosts system.yml

# Apply user changes
ansible-pull -U https://github.com/pbonh/ars-linux.git -i inventory/hosts user.yml
```

Or: `just sync`, `just sync-user`, `just sync-flatpaks`.

## Development

```bash
pip install -r requirements-dev.txt
yamllint .
ansible-lint roles/ system.yml user.yml
pytest
```
