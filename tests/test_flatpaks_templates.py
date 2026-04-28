def test_apps_preinstall_renders(render_template):
    apps = ["com.bitwarden.desktop", "md.obsidian.Obsidian"]
    rendered = render_template(
        "roles/flatpaks/templates/apps.preinstall.j2",
        ars_flatpak_preinstalls=apps,
    )
    for app in apps:
        assert app in rendered
    # Each app block has a [Flatpak Preinstall ...] header
    assert rendered.count("[Flatpak Preinstall") == len(apps)
    # Each block specifies the flathub remote
    assert rendered.count("RemoteUrl=https://flathub.org/repo/flathub.flatpakrepo") == len(apps)


def test_empty_preinstall_list_is_valid(render_template):
    rendered = render_template(
        "roles/flatpaks/templates/apps.preinstall.j2",
        ars_flatpak_preinstalls=[],
    )
    assert rendered.strip() == "" or "Preinstall" not in rendered
