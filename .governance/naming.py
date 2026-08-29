"""Keep development identifiers neutral and free of assistant fingerprints."""

from __future__ import annotations

import re

BRANCH_PATTERN = re.compile(
    r"^(?:feature|fix|hotfix|chore|docs|refactor|test)/[a-z0-9]+(?:-[a-z0-9]+)*$"
)
ASSISTANT_FINGERPRINT = re.compile(
    r"(?:\b(?:assistant|claude|codex|chatgpt|copilot|gpt|llm|openai)\b|"
    r"\bai[- ](?:generated|authored|assisted)\b|"
    r"\b(?:agent|bot)[- ]generated\b|"
    r"co-authored-by:.*\b(?:claude|codex|chatgpt|copilot|bot)\b)",
    re.IGNORECASE,
)
CODEX_TEMP_BRANCH = re.compile(
    r"^(?:codex/[a-z0-9]+(?:-[a-z0-9]+)*-[a-f0-9]{6}"
    r"|worktree-[a-z0-9]+(?:-[a-z0-9]+)*)$"
)


def temporary_codex_branch(branch: str) -> bool:
    """Tell whether Claude Desktop created this temporary task branch."""
    return bool(CLAUDE_TEMP_BRANCH.fullmatch(branch))


def fingerprint_problems(text: str) -> list[str]:
    """Report wording that advertises assistant involvement."""
    if ASSISTANT_FINGERPRINT.search(text):
        return ["assistant-identifying wording is not allowed"]
    return []


def branch_name_problems(branch: str) -> list[str]:
    """Require a neutral, task-specific branch name."""
    problems = fingerprint_problems(branch)
    if not BRANCH_PATTERN.fullmatch(branch):
        problems.append(
            "branch must use '<type>/<lowercase-task>' with a supported task type"
        )
    return problems
