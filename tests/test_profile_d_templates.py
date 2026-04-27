import pytest

EXPECTED = {
    "atuin.sh.j2":   ('atuin init', "atuin"),
    "blesh.sh.j2":   ('blesh', "ble.sh"),
    "brew.sh.j2":    ('brew shellenv', "brew"),
    "carapace.sh.j2":('carapace _carapace', "carapace"),
    "fzf.sh.j2":     ('fzf', "fzf"),
    "mise.sh.j2":    ('mise activate', "mise"),
    "starship.sh.j2":('starship init', "starship"),
    "zoxide.sh.j2":  ('zoxide init', "zoxide"),
}


@pytest.mark.parametrize("name,markers", list(EXPECTED.items()))
def test_profile_d_renders_with_bash_guard(render_template, name, markers):
    rendered = render_template(f"roles/profile_d/templates/{name}")
    needle, tool = markers
    # Each snippet must guard on the tool being installed before sourcing.
    assert "command -v" in rendered, f"{name} missing `command -v` guard"
    assert tool in rendered
    assert needle in rendered
