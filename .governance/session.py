"""Validate repository, worktree, and task-branch identity."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any, Optional

import naming

STATE_DIRECTORY = Path(".governance/state")
TASK_MARKER = STATE_DIRECTORY / "task.json"
PROTECTED_PATHS = (".codex", ".governance", ".githooks", "AGENTS.md")
PROTECTED_BRANCHES = frozenset({"main"})
GOVERNANCE_BRANCH_MARKER = "governance"


class GovernanceStateError(RuntimeError):
    """Report repository state that cannot safely host task work."""


def run_git(*args: str, cwd: Optional[Path] = None, check: bool = True) -> str:
    """Run Git without a shell and return its text output."""
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
    ) as exc:
        if check:
            raise GovernanceStateError(
                f"Git failed while running {' '.join(args)}"
            ) from exc
        return ""
    return result.stdout


def git_succeeds(*args: str, cwd: Optional[Path] = None) -> bool:
    """Return whether a read-only Git query succeeds."""
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    return result.returncode == 0


def repo_root(cwd: Optional[Path] = None) -> Optional[Path]:
    """Return the current checkout root, or nothing outside Git."""
    output = run_git("rev-parse", "--show-toplevel", cwd=cwd, check=False).strip()
    return Path(output).resolve() if output else None


def main_checkout(cwd: Optional[Path] = None) -> Optional[Path]:
    """Return the original checkout that owns the shared Git data."""
    common = run_git(
        "rev-parse",
        "--path-format=absolute",
        "--git-common-dir",
        cwd=cwd,
        check=False,
    ).strip()
    return Path(common).resolve().parent if common else None


def in_worktree(cwd: Optional[Path] = None) -> bool:
    """Tell whether the current checkout is a linked Git worktree."""
    root = repo_root(cwd)
    main = main_checkout(cwd)
    return bool(root and main and root != main)


def current_branch(cwd: Optional[Path] = None) -> str:
    """Return the checked-out branch, or an empty value when detached."""
    return run_git("branch", "--show-current", cwd=cwd, check=False).strip()


def current_head(cwd: Optional[Path] = None) -> str:
    """Return the current commit identifier, or an empty value on failure."""
    return run_git("rev-parse", "HEAD", cwd=cwd, check=False).strip()


def main_head(cwd: Optional[Path] = None) -> str:
    """Return the current main branch commit."""
    return run_git(
        "rev-parse", "--verify", "refs/heads/main", cwd=cwd, check=False
    ).strip()


def origin_main_head(cwd: Optional[Path] = None) -> str:
    """Return the last fetched origin main commit when it exists."""
    return run_git(
        "rev-parse", "--verify", "refs/remotes/origin/main", cwd=cwd, check=False
    ).strip()


def base_head(cwd: Optional[Path] = None) -> str:
    """Return the remote main commit, falling back to local main."""
    return origin_main_head(cwd) or main_head(cwd)


def main_merge_in_progress(cwd: Optional[Path] = None) -> bool:
    """Tell whether a main-branch merge needs conflict resolution."""
    merge_head = run_git(
        "rev-parse", "-q", "--verify", "MERGE_HEAD", cwd=cwd, check=False
    ).strip()
    return bool(merge_head and merge_head == main_head(cwd))


def governance_branch(cwd: Optional[Path] = None) -> bool:
    """Tell whether this branch is dedicated to development governance."""
    return GOVERNANCE_BRANCH_MARKER in current_branch(cwd)


def temporary_codex_branch(branch: str) -> bool:
    """Tell whether Codex created this temporary branch."""
    return naming.temporary_codex_branch(branch)


def branch_name_problems(branch: str) -> list[str]:
    """Return naming problems for one proposed task branch."""
    return naming.branch_name_problems(branch)


def branch_exists(root: Path, branch: str) -> bool:
    """Tell whether a local branch already uses the proposed name."""
    return git_succeeds(
        "show-ref", "--verify", "--quiet", f"refs/heads/{branch}", cwd=root
    )


def _main_base(root: Path) -> tuple[Path, str, str]:
    """Return the protected main-checkout branch and its current commit."""
    main = main_checkout(root)
    if main is None:
        raise GovernanceStateError("Main checkout could not be determined")
    branch = current_branch(main)
    if branch not in PROTECTED_BRANCHES:
        raise GovernanceStateError(
            "Main checkout must be on main before task work starts"
        )
    head = current_head(main)
    if not head:
        raise GovernanceStateError("Main checkout HEAD could not be determined")
    return main, branch, head


def validate_temporary_context(root: Path) -> None:
    """Require a clean, current Codex temporary worktree."""
    if not in_worktree(root):
        raise GovernanceStateError(
            "Codex temporary branches are valid only in a linked worktree"
        )
    branch = current_branch(root)
    if not temporary_codex_branch(branch):
        raise GovernanceStateError(
            "Current branch is not a recognized Codex temporary branch"
        )
    status = run_git("status", "--porcelain=v1", "--untracked-files=all", cwd=root)
    if status.strip():
        raise GovernanceStateError(
            "Temporary worktree already has changes; rename must happen before modification"
        )
    _, base_branch, _ = _main_base(root)
    current_base = base_head(root)
    if not current_base:
        raise GovernanceStateError("main branch could not be resolved")
    if not git_succeeds("merge-base", "--is-ancestor", current_base, "HEAD", cwd=root):
        raise GovernanceStateError(
            f"Temporary worktree does not contain current origin/{base_branch} "
            f"({current_base[:12]})"
        )


def validate_temporary_rename(root: Path, destination: str) -> None:
    """Validate the one permitted temporary-to-task branch rename."""
    validate_temporary_context(root)
    if destination in PROTECTED_BRANCHES:
        raise GovernanceStateError(
            f"Protected branch '{destination}' cannot own task work"
        )
    problems = branch_name_problems(destination)
    if problems:
        raise GovernanceStateError("; ".join(problems))
    if branch_exists(root, destination):
        raise GovernanceStateError(f"Destination branch '{destination}' already exists")


def _write_json(path: Path, payload: Any) -> None:
    """Replace a JSON state file atomically."""
    temporary = path.with_suffix(f"{path.suffix}.{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(
            json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8"
        )
        os.replace(temporary, path)
    except OSError as exc:
        try:
            temporary.unlink()
        except OSError:
            pass
        raise GovernanceStateError("Cannot write task binding state") from exc


def _read_json(path: Path, default: Any) -> Any:
    """Read JSON state and reject damaged content."""
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GovernanceStateError("Cannot read task binding state") from exc


def validate_task_context(root: Path) -> None:
    """Require one linked worktree bound to one current task branch."""
    if not in_worktree(root):
        raise GovernanceStateError(
            "Implementation requires a dedicated linked worktree"
        )
    branch = current_branch(root)
    if not branch:
        raise GovernanceStateError(
            "Implementation requires a dedicated branch, not detached HEAD"
        )
    if branch in PROTECTED_BRANCHES:
        raise GovernanceStateError(
            f"Implementation cannot run on protected branch '{branch}'"
        )
    problems = branch_name_problems(branch)
    if problems:
        raise GovernanceStateError("Invalid task branch: " + "; ".join(problems))

    current_base = base_head(root)
    if not current_base:
        raise GovernanceStateError("main branch could not be resolved")
    if not git_succeeds("merge-base", "--is-ancestor", current_base, "HEAD", cwd=root):
        raise GovernanceStateError(
            f"Task branch does not contain current main "
            f"({current_base[:12]})"
        )

    marker = root / TASK_MARKER
    existing = _read_json(marker, None)
    identity = {"worktree_root": str(root.resolve()), "branch": branch}
    if existing is None:
        _, base_branch, starting_head = _main_base(root)
        if not git_succeeds(
            "merge-base", "--is-ancestor", starting_head, "HEAD", cwd=root
        ):
            raise GovernanceStateError(
                f"Task branch does not contain current {base_branch} HEAD "
                f"({starting_head[:12]})"
            )
        _write_json(marker, {**identity, "base_head": starting_head})
        return
    if not isinstance(existing, dict) or any(
        existing.get(key) != value for key, value in identity.items()
    ):
        raise GovernanceStateError(
            "This worktree is already bound to another task branch; "
            "create a new worktree"
        )
    if not existing.get("base_head"):
        main = main_checkout(root)
        checkout_head = current_head(main) if main else ""
        existing["base_head"] = run_git(
            "merge-base", "HEAD", checkout_head, cwd=root
        ).strip()
        _write_json(marker, existing)


def resolve_target(target: str, cwd: Path) -> Path:
    """Normalize a tool path without trusting dots or symbolic links."""
    candidate = Path(target)
    if not candidate.is_absolute():
        candidate = cwd / candidate
    return candidate.resolve(strict=False)


def inside(path: Path, directory: Path) -> bool:
    """Tell whether a normalized path is inside a directory."""
    try:
        path.relative_to(directory)
        return True
    except ValueError:
        return False


def protected_path(path: Path, root: Path) -> bool:
    """Tell whether a path controls this governance system."""
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError:
        return False
    return any(
        relative == item or relative.startswith(f"{item}/") for item in PROTECTED_PATHS
    )


def recent_commits(root: Path, limit: int = 5) -> list[str]:
    """Return recent commits that may still need improvement."""
    output = run_git("log", f"-{limit}", "--format=%h %s", cwd=root, check=False)
    return [line for line in output.splitlines() if line]


def task_has_commits(root: Path) -> bool:
    """Tell whether HEAD moved beyond this worktree's recorded task start."""
    marker = _read_json(root / TASK_MARKER, {})
    base_head = marker.get("base_head", "") if isinstance(marker, dict) else ""
    return bool(base_head and current_head(root) != base_head)
