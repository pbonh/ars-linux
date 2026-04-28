import os
import shutil
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "roles/bootc_image/files/relocate-opt.sh"


def _stage_fake_opt(tmp_path: Path, name: str, exec_name: str = None) -> Path:
    exec_name = exec_name or name
    base = tmp_path / "opt" / name
    bin_dir = base
    bin_dir.mkdir(parents=True)
    (bin_dir / exec_name).write_text("#!/bin/sh\necho fake\n")
    (bin_dir / exec_name).chmod(0o755)
    desktop_dir = tmp_path / "usr/share/applications"
    desktop_dir.mkdir(parents=True, exist_ok=True)
    (desktop_dir / f"{name}.desktop").write_text(
        f"[Desktop Entry]\nName={name}\nExec=/opt/{name}/{exec_name}\nIcon={name}\n"
    )
    return base


def test_script_is_executable():
    assert os.access(SCRIPT, os.X_OK), "relocate-opt.sh must be chmod +x"


def test_script_relocates_brave_and_rewrites_desktop_exec(tmp_path):
    _stage_fake_opt(tmp_path, "brave.com", exec_name="brave")
    env = {**os.environ, "ARS_RELOCATE_ROOT": str(tmp_path)}
    subprocess.run(["bash", str(SCRIPT)], env=env, check=True)

    assert (tmp_path / "usr/lib/brave.com/brave").exists(), "brave should be moved to /usr/lib"
    desktop = (tmp_path / "usr/share/applications/brave.com.desktop").read_text()
    assert "Exec=/usr/lib/brave.com/brave" in desktop
    assert "/opt/brave.com" not in desktop
