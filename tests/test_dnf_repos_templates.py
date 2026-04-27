import pytest


@pytest.mark.parametrize("template,must_contain", [
    ("roles/dnf_repos/templates/brave-browser.repo.j2",
     ["[brave-browser]", "https://brave-browser-rpm-release.s3.brave.com/x86_64/", "gpgcheck=1"]),
    ("roles/dnf_repos/templates/docker-ce.repo.j2",
     ["[docker-ce-stable]", "https://download.docker.com/linux/fedora/$releasever/$basearch/stable", "gpgcheck=1"]),
    ("roles/dnf_repos/templates/_copr_atim_starship.repo.j2",
     ["[copr:copr.fedorainfracloud.org:atim:starship]", "starship", "fedora-44", "gpgcheck=1"]),
    ("roles/dnf_repos/templates/_copr_scottames_ghostty.repo.j2",
     ["[copr:copr.fedorainfracloud.org:scottames:ghostty]", "ghostty", "fedora-44", "gpgcheck=1"]),
    ("roles/dnf_repos/templates/_copr_wezfurlong_wezterm-nightly.repo.j2",
     ["[copr:copr.fedorainfracloud.org:wezfurlong:wezterm-nightly]", "wezterm", "fedora-44", "gpgcheck=1"]),
])
def test_repo_renders(render_template, template, must_contain):
    rendered = render_template(template, ansible_distribution_major_version="44")
    for needle in must_contain:
        assert needle in rendered, f"missing {needle!r} in {template}\n{rendered}"
