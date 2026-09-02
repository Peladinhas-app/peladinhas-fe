"""Bind one user-approved push to the current repository identity."""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

import readiness
import session as governance_session

TOKEN_TTL_SECONDS = 600
APPROVAL_PHRASE = "APPROVE PUSH"
STATE_RELATIVE_PATH = Path(".governance/state/push-approval.json")
PROTECTED_BRANCHES = frozenset({"main"})


def _git(*args: str, cwd: Optional[Path] = None, check: bool = True) -> str:
    """Run Git and return text without invoking a shell."""
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=check,
            timeout=30,
        )
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ):
        return ""
    return result.stdout.strip()


def repo_root(cwd: Optional[Path] = None) -> Optional[Path]:
    """Return the active checkout root."""
    output = _git("rev-parse", "--show-toplevel", cwd=cwd)
    return Path(output).resolve() if output else None


def state_path(root: Path) -> Path:
    """Return this worktree's push-approval state path."""
    return root / STATE_RELATIVE_PATH


def identity(root: Path) -> dict[str, str]:
    """Describe the exact repository, worktree, branch, and commit."""
    common = _git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=root)
    return {
        "repo_git_dir": str(Path(common).resolve()) if common else "",
        "worktree_root": str(root.resolve()),
        "branch": _git("branch", "--show-current", cwd=root),
        "head": _git("rev-parse", "HEAD", cwd=root),
    }


def in_linked_worktree(root: Path) -> bool:
    """Tell whether approval is being issued from a linked worktree."""
    common = _git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=root)
    if not common:
        return False
    return root.resolve() != Path(common).resolve().parent


def issue(root: Path, session_id: str = "") -> dict[str, object]:
    """Retest one synchronized HEAD and create its short-lived approval."""
    if not in_linked_worktree(root):
        raise RuntimeError("cannot approve a push outside a dedicated task worktree")
    current = identity(root)
    if not current["branch"]:
        raise RuntimeError("cannot approve a push from detached HEAD")
    if current["branch"] in PROTECTED_BRANCHES:
        raise RuntimeError("cannot approve a direct push from a protected branch")
    try:
        validation = readiness.validate_final(root, reuse_receipt=False)
    except governance_session.GovernanceStateError as exc:
        raise RuntimeError(str(exc)) from exc
    now = int(time.time())
    token: dict[str, object] = {
        **current,
        "main_head": validation["main_head"],
        "tested_head": validation["head"],
        "tests_passed_at": validation["passed_at"],
        "issued_at": now,
        "expires_at": now + TOKEN_TTL_SECONDS,
        "session_id": session_id,
        "nonce": secrets.token_hex(24),
        "consumed": False,
    }
    target = state_path(root)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(f".json.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(token, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, target)
    return token


def check(root: Path) -> tuple[bool, str]:
    """Verify that an unused approval still matches this exact HEAD."""
    if not in_linked_worktree(root):
        return False, "Pushes must originate in a dedicated task worktree."
    target = state_path(root)
    try:
        token = json.loads(target.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return False, f"No push approval. Ask for exact response '{APPROVAL_PHRASE}'."
    except (OSError, json.JSONDecodeError):
        return False, "Push approval state is unreadable."
    if token.get("consumed"):
        return False, "Push approval was already consumed."
    if int(time.time()) >= int(token.get("expires_at", 0)):
        return False, "Push approval expired."
    for key, actual in identity(root).items():
        if token.get(key) != actual:
            return False, f"Push approval no longer matches {key.replace('_', ' ')}."
    try:
        current_main = readiness.fetch_main(root)
    except governance_session.GovernanceStateError as exc:
        return False, str(exc)
    if token.get("main_head") != current_main:
        return False, "origin/main changed after validation; synchronize and retest."
    if token.get("tested_head") != identity(root)["head"]:
        return False, "Current HEAD was not the commit that passed final tests."
    return True, "Approved exact branch and HEAD."


def check_refs(root: Path, lines: list[str]) -> tuple[bool, str]:
    """Require one pushed branch ref to match the approved branch and HEAD."""
    allowed, reason = check(root)
    if not allowed:
        return False, reason
    try:
        token = json.loads(state_path(root).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False, "Push approval state is unreadable."
    updates = [line.split() for line in lines if line.strip()]
    if len(updates) != 1 or len(updates[0]) != 4:
        return False, "Approval permits exactly one branch update."
    _, local_sha, remote_ref, _ = updates[0]
    expected_ref = f"refs/heads/{token['branch']}"
    if remote_ref != expected_ref:
        return False, f"Approval permits only destination {expected_ref}."
    if local_sha != token["head"]:
        return False, "Pushed commit does not match the approved HEAD."
    return True, "Approved exact branch ref and HEAD."


def consume(root: Path) -> bool:
    """Mark the approved push attempt as used."""
    target = state_path(root)
    try:
        token = json.loads(target.read_text(encoding="utf-8"))
        token["consumed"] = True
        token["consumed_at"] = int(time.time())
        temporary = target.with_suffix(f".json.{os.getpid()}.tmp")
        temporary.write_text(json.dumps(token, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(temporary, target)
        return True
    except (OSError, json.JSONDecodeError):
        return False


def _main() -> int:
    """Provide the command interface used by prompt and Git hooks."""
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    root = repo_root()
    if root is None:
        print("push-approval: not inside a Git repository", file=sys.stderr)
        return 1
    if command == "issue":
        try:
            token = issue(root)
        except RuntimeError as exc:
            print(f"push-approval: {exc}", file=sys.stderr)
            return 1
        print(f"Push approved until {token['expires_at']}")
        return 0
    if command in ("check", "verify"):
        allowed, reason = check(root)
        if not allowed:
            print(f"push-approval: {reason}", file=sys.stderr)
            return 1
        return 0
    if command == "check-refs" and len(sys.argv) == 3:
        try:
            lines = Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
        except OSError as exc:
            print(f"push-approval: cannot read proposed refs: {exc}", file=sys.stderr)
            return 1
        allowed, reason = check_refs(root, lines)
        if not allowed:
            print(f"push-approval: {reason}", file=sys.stderr)
            return 1
        return 0
    if command == "consume":
        return 0 if consume(root) else 1
    print(f"push-approval: unknown command {command!r}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(_main())
