"""Synchronize main and validate the exact commit before completion or push."""

from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path

import checks
import session

MAIN_REF = "refs/remotes/origin/main"
RECEIPT_PATH = session.STATE_DIRECTORY / "final-validation.json"
FETCH_TIMEOUT_SECONDS = 120
TEST_TIMEOUT_SECONDS = 1800
TEST_ARGUMENTS = (str(Path(".governance/tests/test_governance.py")),)


def _run_git(root: Path, *arguments: str) -> str:
    """Run a required Git command and return its output."""
    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
            timeout=FETCH_TIMEOUT_SECONDS,
        )
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ) as exc:
        detail = getattr(exc, "stderr", "") or str(exc)
        raise session.GovernanceStateError(
            f"Git synchronization failed: {detail.strip()}"
        ) from exc
    return result.stdout.strip()


def fetch_main(root: Path) -> str:
    """Fetch main or safely use local main before the first push."""
    try:
        _run_git(root, "fetch", "--quiet", "origin", "main")
    except session.GovernanceStateError as exc:
        if "couldn't find remote ref main" not in str(exc):
            raise
        head = session.main_head(root)
        if head:
            return head
        raise
    head = session.run_git("rev-parse", MAIN_REF, cwd=root, check=False).strip()
    if not head:
        raise session.GovernanceStateError("origin/main is unavailable after fetch")
    return head


def require_clean(root: Path) -> None:
    """Require tests to describe the exact committed working tree."""
    status = session.run_git(
        "status", "--porcelain=v1", "--untracked-files=all", cwd=root
    ).strip()
    if status:
        raise session.GovernanceStateError(
            "final validation requires a clean worktree; commit or remove all changes"
        )


def require_integrated(root: Path, main_head: str) -> None:
    """Require the task commit to contain the fetched main revision."""
    if not session.git_succeeds(
        "merge-base", "--is-ancestor", main_head, "HEAD", cwd=root
    ):
        raise session.GovernanceStateError(
            f"task branch does not contain current origin/main ({main_head[:12]}); "
            "integrate main before continuing"
        )


def synchronize_start(root: Path) -> str:
    """Fetch main and fast-forward an unchanged task start when possible."""
    require_clean(root)
    fetched_head = fetch_main(root)
    head = session.current_head(root)
    if head == fetched_head or session.git_succeeds(
        "merge-base", "--is-ancestor", fetched_head, "HEAD", cwd=root
    ):
        return fetched_head
    if session.git_succeeds(
        "merge-base", "--is-ancestor", "HEAD", fetched_head, cwd=root
    ):
        _run_git(root, "merge", "--ff-only", MAIN_REF)
        return fetched_head
    raise session.GovernanceStateError(
        f"task branch diverged from current origin/main ({fetched_head[:12]}); "
        "integrate main before implementation"
    )


def _receipt(root: Path) -> dict[str, object]:
    """Read the most recent successful final-validation receipt."""
    try:
        value = json.loads((root / RECEIPT_PATH).read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _write_receipt(root: Path, payload: dict[str, object]) -> None:
    """Persist one successful exact-HEAD validation atomically."""
    target = root / RECEIPT_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(f".json.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, target)


def run_full_tests(root: Path) -> None:
    """Run the repository's complete governance test suite."""
    command = [checks.python_interpreter(root), *TEST_ARGUMENTS]
    try:
        result = subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            timeout=TEST_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        raise session.GovernanceStateError(
            f"full test suite timed out after {TEST_TIMEOUT_SECONDS} seconds"
        ) from exc
    except FileNotFoundError as exc:
        raise session.GovernanceStateError(
            "Python is unavailable for final tests"
        ) from exc
    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip().splitlines()[-40:]
        raise session.GovernanceStateError(
            "full test suite failed:\n" + "\n".join(output)
        )


def validate_final(root: Path, *, reuse_receipt: bool) -> dict[str, object]:
    """Fetch main, require integration, and test the exact clean HEAD."""
    session.validate_task_context(root)
    require_clean(root)
    fetched_head = fetch_main(root)
    require_integrated(root, fetched_head)
    head = session.current_head(root)
    expected = {
        "head": head,
        "main_head": fetched_head,
        "test_arguments": list(TEST_ARGUMENTS),
    }
    if reuse_receipt and all(
        _receipt(root).get(key) == value for key, value in expected.items()
    ):
        return _receipt(root)
    run_full_tests(root)
    receipt = {**expected, "passed_at": int(time.time())}
    _write_receipt(root, receipt)
    return receipt
