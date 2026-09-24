"""Bind one user-approved push to the current repository identity."""

from __future__ import annotations

import json
import os
import secrets
import hashlib
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

import readiness
import session as governance_session

TOKEN_TTL_SECONDS = 600
APPROVAL_PHRASE = "APPROVE PUSH"
BOOTSTRAP_APPROVAL_PHRASE = "APPROVE MAIN BOOTSTRAP"
STATE_RELATIVE_PATH = Path(".governance/state/push-approval.json")
PROTECTED_BRANCHES = frozenset({"main"})
ZERO_SHA = "0" * 40
BOOTSTRAP_STATE_GIT_PATH = "governance/main-bootstrap-approval.json"
BOOTSTRAP_CHECKS = (
    (".githooks/secret_scan.py",),
    (".governance/tests/test_governance.py",),
)


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


def bootstrap_state_path(root: Path) -> Path:
    """Return the private Git path for main bootstrap approval."""
    output = _git("rev-parse", "--git-path", BOOTSTRAP_STATE_GIT_PATH, cwd=root)
    if not output:
        raise RuntimeError("cannot resolve bootstrap approval state path")
    return (root / output).resolve() if not Path(output).is_absolute() else Path(output)


def identity(root: Path) -> dict[str, str]:
    """Describe the exact repository, worktree, branch, and commit."""
    common = _git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=root)
    return {
        "repo_git_dir": str(Path(common).resolve()) if common else "",
        "worktree_root": str(root.resolve()),
        "branch": _git("branch", "--show-current", cwd=root),
        "head": _git("rev-parse", "HEAD", cwd=root),
    }


def clean_worktree(root: Path) -> bool:
    """Tell whether the checkout has no pending file changes."""
    status = _git(
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
        cwd=root,
        check=False,
    )
    return not status.strip()


def remote_branch_heads(root: Path, remote: str) -> tuple[bool, list[str]]:
    """Read live remote branch heads; failures are not treated as empty."""
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--heads", remote],
            cwd=str(root),
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False, []
    if result.returncode != 0:
        return False, []
    heads = [line for line in result.stdout.splitlines() if line.strip()]
    return True, heads


def remote_push_url_fingerprint(root: Path, remote: str) -> str:
    """Return a stable fingerprint for the exact remote push URL."""
    url = _git("remote", "get-url", "--push", remote, cwd=root)
    if not url:
        raise RuntimeError("Remote push URL could not be resolved.")
    return hashlib.sha256(url.encode("utf-8", "surrogateescape")).hexdigest()


def remote_has_no_branch_heads(root: Path, remote: str) -> tuple[bool, str]:
    """Confirm the configured remote has no branch heads right now."""
    ok, heads = remote_branch_heads(root, remote)
    if not ok:
        return False, "Remote branch lookup failed; bootstrap cannot continue."
    if heads:
        return False, "Remote already has branch heads; bootstrap is not allowed."
    return True, "Remote has no branch heads."


def run_bootstrap_checks(root: Path) -> tuple[bool, str]:
    """Run the local checks required before bootstrapping remote main."""
    python = governance_session.run_git(
        "config", "--get", "governance.python", cwd=root, check=False
    ).strip() or checks_python()
    for command in BOOTSTRAP_CHECKS:
        target = root / command[0]
        if not target.exists():
            return False, f"Required bootstrap check is missing: {command[0]}"
        try:
            result = subprocess.run(
                [python, *command],
                cwd=root,
                capture_output=True,
                text=True,
                timeout=readiness.TEST_TIMEOUT_SECONDS,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False, f"Bootstrap check could not run: {command[0]}"
        if result.returncode != 0:
            output = (result.stdout + result.stderr).strip().splitlines()[-20:]
            detail = "\n".join(output)
            return False, f"Bootstrap check failed: {command[0]}\n{detail}"
    return True, "Bootstrap checks passed."


def checks_python() -> str:
    """Return a Python command for governance checks."""
    return governance_session.run_git(
        "config", "--get", "governance.python", check=False
    ).strip() or sys.executable


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


def issue_main_bootstrap(root: Path, phrase: str, remote: str = "origin") -> dict[str, object]:
    """Record one approval for creating origin/main from local main."""
    if phrase != BOOTSTRAP_APPROVAL_PHRASE:
        raise RuntimeError(
            f"main bootstrap requires exact phrase '{BOOTSTRAP_APPROVAL_PHRASE}'"
        )
    current = identity(root)
    if current["branch"] != "main":
        raise RuntimeError("main bootstrap approval must be issued from local main")
    if not clean_worktree(root):
        raise RuntimeError("main bootstrap approval requires a clean worktree")
    local_main = governance_session.main_head(root)
    if not local_main or local_main != current["head"]:
        raise RuntimeError("checked-out HEAD must match local main")
    remote_empty, reason = remote_has_no_branch_heads(root, remote)
    if not remote_empty:
        raise RuntimeError(reason)
    try:
        remote_fingerprint = remote_push_url_fingerprint(root, remote)
    except RuntimeError as exc:
        raise RuntimeError(str(exc)) from exc
    checks_ok, checks_reason = run_bootstrap_checks(root)
    if not checks_ok:
        raise RuntimeError(checks_reason)

    now = int(time.time())
    token: dict[str, object] = {
        **current,
        "action": "main_bootstrap",
        "approved_head": current["head"],
        "remote": remote,
        "remote_push_url_sha256": remote_fingerprint,
        "issued_at": now,
        "nonce": secrets.token_hex(24),
    }
    target = bootstrap_state_path(root)
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


def check_main_bootstrap_refs(
    root: Path, lines: list[str], remote: str = "origin"
) -> tuple[bool, str]:
    """Allow only the first creation of remote main from clean local main."""
    updates = [line.split() for line in lines if line.strip()]
    if len(updates) != 1 or len(updates[0]) != 4:
        return False, "Main bootstrap permits exactly one ref update."

    local_ref, local_sha, remote_ref, remote_sha = updates[0]
    if local_ref != "refs/heads/main":
        return False, "Main bootstrap source must be refs/heads/main."
    if remote_ref != "refs/heads/main":
        return False, "Main bootstrap destination must be refs/heads/main."
    if remote_sha != ZERO_SHA:
        return False, "Main bootstrap only creates a missing remote main."
    current = identity(root)
    if current["branch"] != "main":
        return False, "Main bootstrap must run from local main."
    local_main = governance_session.main_head(root)
    if not local_main or current["head"] != local_main:
        return False, "Current checkout must be local main."
    if local_sha != local_main:
        return False, "Pushed SHA must match local main."
    if not clean_worktree(root):
        return False, "Main bootstrap requires a clean worktree."

    try:
        token = json.loads(bootstrap_state_path(root).read_text(encoding="utf-8"))
    except FileNotFoundError:
        return False, (
            "No main bootstrap approval. Use exact phrase "
            f"'{BOOTSTRAP_APPROVAL_PHRASE}'."
        )
    except (OSError, json.JSONDecodeError, RuntimeError):
        return False, "Main bootstrap approval state is unreadable."
    if token.get("action") != "main_bootstrap":
        return False, "Main bootstrap approval has the wrong action."
    if token.get("remote") != remote:
        return False, "Main bootstrap approval was issued for another remote."
    try:
        remote_fingerprint = remote_push_url_fingerprint(root, remote)
    except RuntimeError:
        return False, "Remote push URL could not be resolved."
    if token.get("remote_push_url_sha256") != remote_fingerprint:
        return False, "Main bootstrap approval was issued for another remote URL."
    if token.get("approved_head") != local_main:
        return False, "Main bootstrap approval was issued for another commit."
    for key, actual in current.items():
        if token.get(key) != actual:
            return False, f"Main bootstrap approval no longer matches {key}."

    remote_empty, reason = remote_has_no_branch_heads(root, remote)
    if not remote_empty:
        return False, reason
    checks_ok, checks_reason = run_bootstrap_checks(root)
    if not checks_ok:
        return False, checks_reason
    return True, "Approved initial remote main bootstrap."


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


def consume_main_bootstrap(root: Path) -> bool:
    """Remove the private bootstrap approval after one push attempt."""
    try:
        bootstrap_state_path(root).unlink()
        return True
    except FileNotFoundError:
        return True
    except (OSError, RuntimeError):
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
    if command == "issue-main-bootstrap":
        phrase = sys.argv[2] if len(sys.argv) == 3 else ""
        try:
            token = issue_main_bootstrap(root, phrase)
        except RuntimeError as exc:
            print(f"push-approval: {exc}", file=sys.stderr)
            return 1
        print(f"Main bootstrap approved for {token['approved_head']}")
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
    if command == "check-main-bootstrap-refs" and len(sys.argv) in (3, 4):
        remote = sys.argv[3] if len(sys.argv) == 4 else "origin"
        try:
            lines = Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
        except OSError as exc:
            print(f"push-approval: cannot read proposed refs: {exc}", file=sys.stderr)
            return 1
        allowed, reason = check_main_bootstrap_refs(root, lines, remote)
        if not allowed:
            print(f"push-approval: {reason}", file=sys.stderr)
            return 1
        return 0
    if command == "consume":
        return 0 if consume(root) else 1
    if command == "consume-main-bootstrap":
        return 0 if consume_main_bootstrap(root) else 1
    print(f"push-approval: unknown command {command!r}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(_main())
