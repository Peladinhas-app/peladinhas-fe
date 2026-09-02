#!/usr/bin/env python3
"""Validate concise, professional commit and pull-request messages."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

GOVERNANCE = Path(__file__).resolve().parents[1] / ".governance"
sys.path.insert(0, str(GOVERNANCE))

from naming import branch_name_problems, fingerprint_problems  # noqa: E402

ALLOWED_TYPES = (
    "feat",
    "fix",
    "refactor",
    "chore",
    "docs",
    "test",
    "perf",
    "ci",
    "build",
    "style",
)
SUBJECT_PATTERN = re.compile(
    r"^(?P<type>" + "|".join(ALLOWED_TYPES) + r")"
    r"(?P<scope>\([a-zA-Z0-9_.\-]+\))?"
    r"(?P<breaking>!)?"
    r": (?P<description>.+)$"
)
DIRECT_ADDRESS = re.compile(
    r"\b(?:you|your|yours|yourself|yourselves)\b", re.IGNORECASE
)
EMOJI = re.compile("[\U0001F000-\U0001FAFF\U00002600-\U000027BF]")
MAX_SUBJECT_LENGTH = 72
MAX_COMMIT_DETAILS_WORDS = 100
MAX_PR_SUMMARY_WORDS = 30
MAX_PR_DETAILS_WORDS = 160
MAX_BODY_LINE_LENGTH = 120


def _subject_problems(subject: str) -> list[str]:
    """Check the short first line shared by commits and pull requests."""
    problems: list[str] = []
    match = SUBJECT_PATTERN.fullmatch(subject)
    if not match:
        problems.append("title must match '<type>(<scope>): <description>'")
    else:
        description = match.group("description")
        if description[:1].isupper() and not description.split()[0].isupper():
            problems.append("description must start lowercase and use imperative wording")
    if len(subject) > MAX_SUBJECT_LENGTH:
        problems.append(f"title exceeds {MAX_SUBJECT_LENGTH} characters")
    if DIRECT_ADDRESS.search(subject):
        problems.append("direct reader address is not professional or impersonal")
    if EMOJI.search(subject):
        problems.append("emoji is not allowed")
    problems.extend(fingerprint_problems(subject))
    return problems


def validate_commit_message(raw: str) -> list[str]:
    """Check a commit has a short subject followed by concise details."""
    lines = [line.rstrip() for line in raw.splitlines() if not line.startswith("#")]
    while lines and not lines[0]:
        lines.pop(0)
    if not lines:
        return ["commit message is empty"]
    subject = lines[0]
    if subject.startswith(("Merge ", "Revert ")):
        return []
    problems = _subject_problems(subject)
    if len(lines) < 3 or lines[1] or lines[2] != "Details:":
        problems.append("use a blank line followed by the exact 'Details:' label")
        return problems
    details = "\n".join(lines[3:]).strip()
    if not details:
        problems.append("Details must explain the change")
    elif len(details.split()) > MAX_COMMIT_DETAILS_WORDS:
        problems.append(f"Details exceeds {MAX_COMMIT_DETAILS_WORDS} words")
    if any(len(line) > MAX_BODY_LINE_LENGTH for line in lines[3:]):
        problems.append(f"Details lines must not exceed {MAX_BODY_LINE_LENGTH} characters")
    if DIRECT_ADDRESS.search(details):
        problems.append("Details must not address the reader directly")
    if EMOJI.search(details):
        problems.append("Details must not contain emoji")
    problems.extend(fingerprint_problems(details))
    return problems


def _section(body: str, heading: str, following: str | None = None) -> str | None:
    """Return one Markdown section without its heading."""
    end = rf"(?=^## {re.escape(following)}\s*$)" if following else r"\Z"
    match = re.search(
        rf"^## {re.escape(heading)}\s*$\n(?P<content>.*?){end}",
        body,
        re.MULTILINE | re.DOTALL,
    )
    return match.group("content").strip() if match else None


def validate_pr_message(title: str, body: str) -> list[str]:
    """Check a pull request has a short title, summary, and detail."""
    problems = _subject_problems(title.strip())
    clean_body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL).strip()
    headings = re.findall(r"^## (.+?)\s*$", clean_body, re.MULTILINE)
    if headings != ["Summary", "Details"]:
        problems.append("body must contain only '## Summary' then '## Details'")
    summary = _section(clean_body, "Summary", "Details")
    details = _section(clean_body, "Details")
    if summary is None:
        problems.append("body must start with '## Summary' followed by '## Details'")
    elif not summary:
        problems.append("Summary must state the outcome")
    elif len(summary.split()) > MAX_PR_SUMMARY_WORDS:
        problems.append(f"Summary exceeds {MAX_PR_SUMMARY_WORDS} words")
    if details is None:
        problems.append("body must contain '## Details'")
    elif not details:
        problems.append("Details must provide relevant context and validation")
    elif len(details.split()) > MAX_PR_DETAILS_WORDS:
        problems.append(f"Details exceeds {MAX_PR_DETAILS_WORDS} words")
    content = f"{summary or ''}\n{details or ''}"
    if DIRECT_ADDRESS.search(content):
        problems.append("body must not address the reader directly")
    if EMOJI.search(content):
        problems.append("body must not contain emoji")
    problems.extend(fingerprint_problems(content))
    if any(len(line) > MAX_BODY_LINE_LENGTH for line in clean_body.splitlines()):
        problems.append(f"body lines must not exceed {MAX_BODY_LINE_LENGTH} characters")
    return problems


def validate_push_commits(local_sha: str, remote_sha: str) -> list[str]:
    """Check every new commit message included in one push update."""
    zero = "0" * 40
    if remote_sha == zero:
        revision = [local_sha, "--not", "--remotes"]
    else:
        revision = [f"{remote_sha}..{local_sha}"]
    result = subprocess.run(
        ["git", "log", "--format=%H%x00%B%x00", *revision],
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )
    if result.returncode:
        return ["pushed commit messages could not be inspected"]
    fields = [field for field in result.stdout.split("\0") if field.strip()]
    problems: list[str] = []
    for index in range(0, len(fields), 2):
        commit = fields[index].strip()[:12]
        message = fields[index + 1] if index + 1 < len(fields) else ""
        for problem in validate_commit_message(message):
            problems.append(f"commit {commit}: {problem}")
    return problems


def main() -> int:
    """Expose branch and push checks to shell-based Git hooks."""
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "branch" and len(sys.argv) == 3:
        problems = branch_name_problems(sys.argv[2])
    elif command == "commit-message" and len(sys.argv) == 3:
        raw = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
        problems = validate_commit_message(raw)
    elif command == "push-commits" and len(sys.argv) == 4:
        problems = validate_push_commits(sys.argv[2], sys.argv[3])
    else:
        print("message-structure: invalid command", file=sys.stderr)
        return 1
    for problem in problems:
        print(f"message-structure: {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
