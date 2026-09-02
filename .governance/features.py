"""Read optional governance feature switches."""

from __future__ import annotations

import json
from pathlib import Path

CONFIG_PATH = Path(".governance/governance.json")
LOCAL_CONFIG_PATH = Path(".governance/governance.local.json")
DEFAULTS = {
    "semantic_commit_review": True,
}


def values(root: Path) -> dict[str, bool]:
    """Return every optional feature with invalid values replaced."""
    return {name: enabled(root, name) for name in DEFAULTS}


def enabled(root: Path, name: str) -> bool:
    """Return one feature state with an optional local override."""
    if name not in DEFAULTS:
        raise ValueError(f"unknown governance feature: {name}")
    value = DEFAULTS[name]
    for path in (CONFIG_PATH, LOCAL_CONFIG_PATH):
        try:
            payload = json.loads((root / path).read_text(encoding="utf-8"))
            candidate = payload.get("features", {}).get(name)
        except (AttributeError, json.JSONDecodeError, OSError):
            continue
        if isinstance(candidate, bool):
            value = candidate
    return value
