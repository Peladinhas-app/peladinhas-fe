#!/usr/bin/env python3
"""Validate exact staged code and run relevant tests before a commit."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import checks
import session

TEST_TIMEOUT_SECONDS = 1800
GOVERNANCE_PREFIXES = (".codex/", ".governance/", ".githooks/", "AGENTS.md")
GOVERNANCE_TEST = ".governance/tests/test_governance.py"


def _git_bytes(root: Path, *arguments: str) -> bytes:
    """Return exact Git output without filename or encoding loss."""
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        capture_output=True,
        check=True,
        timeout=30,
    )
    return result.stdout


def staged_paths(root: Path) -> list[str]:
    """Return files with staged content in the pending commit."""
    output = _git_bytes(
        root, "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"
    )
    return [
        item.decode("utf-8", "surrogateescape") for item in output.split(b"\0") if item
    ]


def staged_source(root: Path, relative: str) -> str:
    """Read the exact staged blob for one source file."""
    return _git_bytes(root, "show", f":{relative}").decode("utf-8")


def partially_staged_paths(root: Path, paths: list[str]) -> list[str]:
    """Return staged paths whose working copy has additional edits."""
    if not paths:
        return []
    output = _git_bytes(root, "diff", "--name-only", "-z", "--", *paths)
    return [
        item.decode("utf-8", "surrogateescape") for item in output.split(b"\0") if item
    ]


def check_files(root: Path, paths: list[str]) -> list[str]:
    """Return objective coding problems in exact staged source blobs."""
    findings: list[str] = []
    for relative in paths:
        if not checks.relevant_python_path(relative):
            continue
        try:
            source = staged_source(root, relative)
        except (subprocess.SubprocessError, UnicodeError) as exc:
            findings.append(f"{relative}: cannot read staged source: {exc}")
            continue
        findings.extend(
            f"{relative}: {problem}"
            for problem in checks.validate_source(root, relative, source)
        )
    return findings


def related_tests(root: Path, paths: list[str]) -> list[str]:
    """Find staged tests and nearby tests relevant to the commit."""
    targets: set[str] = set()
    if any(path.startswith(GOVERNANCE_PREFIXES) for path in paths):
        targets.add(GOVERNANCE_TEST)

    project_tests = root / "tests"
    for relative in paths:
        normalized = relative.replace("\\", "/")
        if not normalized.endswith(".py"):
            continue
        path = root / normalized
        if path.exists() and (
            "/tests/" in normalized
            or normalized.startswith("tests/")
            or path.name.startswith("test_")
        ):
            targets.add(normalized)
        nearby = path.parent / "tests"
        if nearby.is_dir():
            targets.add(nearby.relative_to(root).as_posix())
        if project_tests.is_dir() and not path.name.startswith("test_"):
            for candidate in project_tests.rglob(f"test_{path.stem}.py"):
                targets.add(candidate.relative_to(root).as_posix())
    return sorted(target for target in targets if (root / target).exists())


def run_tests(root: Path, paths: list[str]) -> list[str]:
    """Run relevant tests and report failures."""
    targets = related_tests(root, paths)
    if not targets:
        return []
    problems: list[str] = []
    python = checks.python_interpreter(root)
    for target in targets:
        path = root / target
        if path.is_dir():
            command = [python, "-m", "unittest", "discover", target]
        else:
            command = [python, target]
        problem = run_test_command(root, command)
        if problem:
            problems.append(problem)
    return problems


def run_test_command(root: Path, command: list[str]) -> str | None:
    """Run one related test command and report any failure."""
    try:
        result = subprocess.run(
            command,
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=TEST_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return f"related tests timed out after {TEST_TIMEOUT_SECONDS} seconds"
    except FileNotFoundError:
        return "related tests could not run because Python is unavailable"
    if result.returncode == 0:
        return None
    output = (result.stdout + result.stderr).strip().splitlines()[-30:]
    return "related tests failed:\n" + "\n".join(output)


def main() -> int:
    """Block a commit when staged changes fail objective validation."""
    root = session.repo_root(Path.cwd())
    if root is None:
        print("commit checks: repository could not be determined", file=sys.stderr)
        return 1
    try:
        session.validate_task_context(root)
        paths = staged_paths(root)
        if not paths:
            print("commit checks: no staged files", file=sys.stderr)
            return 1
        overlaps = partially_staged_paths(root, paths)
        if overlaps:
            print(
                "commit checks: staged files also have unstaged edits; "
                "tests would not validate the exact commit",
                file=sys.stderr,
            )
            for relative in overlaps:
                print(f"  - {relative}", file=sys.stderr)
            return 1
        problems = check_files(root, paths)
        problems.extend(run_tests(root, paths))
    except (OSError, subprocess.SubprocessError, session.GovernanceStateError) as exc:
        print(f"commit checks: failed closed: {exc}", file=sys.stderr)
        return 1
    if problems:
        print("commit checks: commit blocked", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    print("commit checks: deterministic checks and relevant tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
