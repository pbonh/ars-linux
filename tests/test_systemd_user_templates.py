def test_chezmoi_init_renders(render_template):
    out = render_template(
        "roles/systemd_user/templates/chezmoi-init.service.j2",
        ars_zdots_install_path="/usr/share/zirconium/zdots",
    )
    assert "ConditionPathExists=!%h/.config/zirconium/chezmoi" in out
    assert "/usr/share/zirconium/zdots" in out
    assert "WantedBy=graphical-session-pre.target" in out
    assert "ExecStart=" in out
    assert "Type=oneshot" in out


def test_chezmoi_update_service_renders(render_template):
    out = render_template(
        "roles/systemd_user/templates/chezmoi-update.service.j2",
        ars_zdots_install_path="/usr/share/zirconium/zdots",
    )
    assert "/usr/share/zirconium/zdots" in out
    assert "--no-tty" in out
    assert "--keep-going" in out


def test_chezmoi_update_timer_renders(render_template):
    out = render_template(
        "roles/systemd_user/templates/chezmoi-update.timer.j2",
        ars_chezmoi_update_interval="24h",
    )
    assert "OnUnitActiveSec=24h" in out
    assert "WantedBy=timers.target" in out


def test_preset_renders_enabled_units(render_template):
    units = ["chezmoi-init.service", "chezmoi-update.timer", "tailscale-systray.service"]
    out = render_template(
        "roles/systemd_user/templates/01-ars-linux.preset.j2",
        ars_systemd_user_units=units,
    )
    for u in units:
        assert f"enable {u}" in out
