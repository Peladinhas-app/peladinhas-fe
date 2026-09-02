#!/usr/bin/env python3
"""Fail closed until a verified semantic reviewer integration exists."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import features

PROMPT_FILE = Path(__file__).resolve().parent / "prompts" / "semantic_review.md"
INTEGRATION_NOTE = Path(__file__).resolve().parent / "SEMANTIC_REVIEW.md"
MAX_DIFF_CHARACTERS = 300_000


def staged_diff(root: Path) -> str:
    """Return the staged changes that would enter the commit."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--binary", "--no-ext-diff"],
        cwd=root,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=30,
        check=True,
    )
    diff = result.stdout
    if not diff.strip():
        raise RuntimeError("staged diff is empty")
    if len(diff) > MAX_DIFF_CHARACTERS:
        raise RuntimeError(
            "staged diff exceeds semantic-review limit "
            f"({MAX_DIFF_CHARACTERS} characters)"
        )
    return diff


def parse_verdict(text: str) -> dict:
    """Validate the reviewer's complete JSON decision."""
    try:
        verdict = json.loads(text.strip())
    except json.JSONDecodeError as exc:
        raise RuntimeError("semantic reviewer returned malformed JSON") from exc
    if not isinstance(verdict, dict) or set(verdict) != {"pass", "problems"}:
        raise RuntimeError("semantic reviewer returned an invalid result")
    passed = verdict["pass"]
    problems = verdict["problems"]
    if not isinstance(passed, bool) or not isinstance(problems, list):
        raise RuntimeError("semantic reviewer omitted required fields")
    required = {"rule", "file", "issue", "fix"}
    if any(
        not isinstance(problem, dict)
        or set(problem) != required
        or any(not isinstance(problem[key], str) for key in required)
        for problem in problems
    ):
        raise RuntimeError("semantic reviewer returned an invalid problem")
    if passed == bool(problems):
        raise RuntimeError("semantic reviewer returned a contradictory result")
    return verdict


def run_review(root: Path, prompt: str, diff: str) -> dict:
    """Refuse review until the command is verified."""
    _ = (root, prompt, diff)
    raise RuntimeError(
        "no verified non-interactive Codex or OpenAI strict-JSON reviewer "
        f"integration is configured; see {INTEGRATION_NOTE.as_posix()}"
    )


def main() -> int:
    """Block commits when semantic review cannot run safely."""
    try:
        root = Path(
            subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            ).stdout.strip()
        )
        if not features.enabled(root, "semantic_commit_review"):
            print("semantic review: disabled by .governance/governance.json")
            return 0
        prompt = PROMPT_FILE.read_text(encoding="utf-8")
        diff = staged_diff(root)
        verdict = run_review(root, prompt, diff)
    except (
        OSError,
        RuntimeError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
    ) as exc:
        print(f"semantic review failed closed: {exc}", file=sys.stderr)
        return 1
    if verdict["pass"]:
        print("semantic review: passed")
        return 0
    print("semantic review: commit blocked", file=sys.stderr)
    for problem in verdict["problems"]:
        print(
            f"  - {problem['file']}: {problem['issue']} Fix: {problem['fix']}",
            file=sys.stderr,
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
