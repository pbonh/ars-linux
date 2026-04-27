"""Render Jinja2 templates from any role/templates dir without invoking Ansible."""
from __future__ import annotations
from pathlib import Path
import pytest
from jinja2 import Environment, FileSystemLoader, StrictUndefined

REPO_ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture
def render_template():
    def _render(template_relpath: str, **vars_) -> str:
        full = REPO_ROOT / template_relpath
        env = Environment(
            loader=FileSystemLoader(str(full.parent)),
            undefined=StrictUndefined,
            keep_trailing_newline=True,
            trim_blocks=False,
            lstrip_blocks=False,
        )
        return env.get_template(full.name).render(**vars_)
    return _render
