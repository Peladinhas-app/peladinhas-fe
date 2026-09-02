#!/usr/bin/env python3
"""Reject staged environment files and likely credential values."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import PurePosixPath

SECRET_PATTERN = re.compile(
    rb"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
    rb"|AKIA[0-9A-Z]{16}"
    rb"|gh[pousr]_[A-Za-z0-9_]{30,}"
    rb"|(?:SECRET|SECRET_KEY|PASSWORD|API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|"
    rb"CLIENT_SECRET|PRIVATE_KEY)\s*[:=]\s*['\"]"
    rb"[A-Za-z0-9/_.\-]{12,}"
)
EXCLUDED_PATHS = {
    ".githooks/secret_scan.py",
    ".governance/tests/test_governance.py",
}
ENV_TEMPLATE_SUFFIXES = (".example", ".sample", ".template")


def git_bytes(*arguments: str) -> bytes:
    """Read staged repository data directly from Git."""
    result = subprocess.run(
        ["git", *arguments], check=True, capture_output=True, timeout=30
    )
    return result.stdout


def staged_paths() -> list[str]:
    """Return changed staged paths without splitting spaces."""
    output = git_bytes("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    return [
        item.decode("utf-8", "surrogateescape") for item in output.split(b"\0") if item
    ]


def display_path(path: str) -> str:
    """Render unusual filenames without terminal control characters."""
    return path.encode("unicode_escape", "backslashreplace").decode("ascii")


def is_forbidden_env(path: str) -> bool:
    """Identify non-template environment files by their final filename."""
    name = PurePosixPath(path).name
    return (name == ".env" or name.startswith(".env.")) and not name.endswith(
        ENV_TEMPLATE_SUFFIXES
    )


def staged_content(path: str) -> bytes:
    """Read the exact blob proposed for commit."""
    return git_bytes("show", f":{path}")


def main() -> int:
    """Report filenames only and reject any staged secret risk."""
    try:
        paths = staged_paths()
        env_files = [path for path in paths if is_forbidden_env(path)]
        secret_files = []
        for path in paths:
            if path in EXCLUDED_PATHS:
                continue
            content = staged_content(path)
            if b"\0" not in content and SECRET_PATTERN.search(content):
                secret_files.append(path)
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"pre-commit: secret scan failed closed: {exc}", file=sys.stderr)
        return 1

    if env_files:
        print("pre-commit: refusing staged environment file(s):")
        for path in env_files:
            print(f"  - {display_path(path)}")
    if secret_files:
        print("pre-commit: staged files contain possible hardcoded secrets:")
        for path in secret_files:
            print(f"  - {display_path(path)}")
    if env_files or secret_files:
        print("Move credentials to an untracked environment file or secret manager.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
