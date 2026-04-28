import pytest

BASE_VARS = dict(
    ars_base_image="ghcr.io/zirconium-dev/zirconium:latest",
    ars_rpm_packages_all=["kitty", "neovim", "brave-browser"],
    ars_extra_fonts=[],
    ars_dnf_repos={
        "brave-browser.repo": "brave-browser.repo.j2",
        "docker-ce.repo": "docker-ce.repo.j2",
    },
    ars_third_party_rpms=[
        {"name": "vivaldi-stable",
         "url": "https://example.invalid/vivaldi.rpm",
         "sha256": "deadbeef" * 8,
         "post_install": "relocate_opt"},
    ],
    ars_appimages=[
        {"name": "cursor",
         "url": "https://example.invalid/cursor.AppImage",
         "sha256": "feedface" * 8,
         "desktop_exec_override": "/usr/lib/cursor/cursor"},
    ],
    ars_npm_globals=[{"name": "openai-codex", "version": "latest"}],
    ars_zdots_repo="https://github.com/pbonh/zdots.git",
    ars_zdots_branch="main",
    ars_zdots_install_path="/usr/share/zirconium/zdots",
    ars_containerfile_extra_lines=[],
)


def test_containerfile_starts_from_base_image(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert out.splitlines()[0] == "FROM ghcr.io/zirconium-dev/zirconium:latest"


def test_repos_copied_first(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "COPY repos/*.repo /etc/yum.repos.d/" in out


def test_packages_installed(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "dnf -y install kitty neovim brave-browser" in out
    assert "dnf clean all" in out


def test_third_party_rpms_pinned_by_sha(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "https://example.invalid/vivaldi.rpm" in out
    assert ("deadbeef" * 8) in out
    assert "sha256sum -c -" in out


def test_relocate_opt_invoked(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "COPY relocate-opt.sh /tmp/" in out
    assert "/tmp/relocate-opt.sh" in out


def test_appimage_block_present(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "/usr/lib/cursor/Cursor.AppImage" in out
    assert ("feedface" * 8) in out


def test_zdots_cloned_to_install_path(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "git clone --depth 1 --branch main https://github.com/pbonh/zdots.git /usr/share/zirconium/zdots" in out
    assert "rm -rf /usr/share/zirconium/zdots/.git" in out


def test_npm_global_install_uses_npm_config_prefix(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "NPM_CONFIG_PREFIX=/usr npm install -g openai-codex@latest" in out


def test_tmpfiles_dropped(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    assert "COPY tmpfiles/zirconium-opt.conf /usr/lib/tmpfiles.d/" in out


def test_bootc_lint_runs_last(render_template):
    out = render_template("roles/bootc_image/templates/Containerfile.j2", **BASE_VARS)
    lines = [l for l in out.splitlines() if l.strip()]
    assert lines[-1] == "RUN bootc container lint"


def test_extra_fonts_appended_when_set(render_template):
    out = render_template(
        "roles/bootc_image/templates/Containerfile.j2",
        **{**BASE_VARS, "ars_extra_fonts": ["fira-code-fonts"]},
    )
    assert "fira-code-fonts" in out
    assert "fc-cache --force --really-force --system-only" in out


def test_extra_lines_appended_verbatim(render_template):
    out = render_template(
        "roles/bootc_image/templates/Containerfile.j2",
        **{**BASE_VARS, "ars_containerfile_extra_lines": ["RUN echo escape-hatch"]},
    )
    assert "RUN echo escape-hatch" in out
