"""Perform the coding checks that have objective answers."""

from __future__ import annotations

import ast
import io
import re
import subprocess
import sys
import tokenize
from pathlib import Path

MIN_DOCSTRING_WORDS = 4
CHECKED_ROOTS = (
    "app/",
    "serverless/",
    "src/",
    "workers/",
    "tools/",
    "tests/",
    "scripts/",
    ".governance/",
)
SKIPPED_PARTS = ("__pycache__", "migrations", "nltk_data", ".venv", "node_modules")
TBD_PATTERN = re.compile(r"\bTBD\b", re.IGNORECASE)
MAINTAINABILITY_TBD = re.compile(
    r"TBD - maintainability and scalability:\s*\S", re.IGNORECASE
)
SINGLE_SOURCE_TBD = re.compile(r"TBD - one source of [^:]+:\s*\S", re.IGNORECASE)


def python_interpreter(root: Path) -> str:
    """Return the project Python program when it is available."""
    windows = root / ".venv" / "Scripts" / "python.exe"
    posix = root / ".venv" / "bin" / "python3"
    if windows.exists():
        return str(windows)
    if posix.exists():
        return str(posix)
    return sys.executable


def relevant_python_path(relative: str) -> bool:
    """Tell whether a path is maintained Python source."""
    normalized = relative.replace("\\", "/")
    return (
        normalized.endswith(".py")
        and normalized.startswith(CHECKED_ROOTS)
        and not any(part in normalized.split("/") for part in SKIPPED_PARTS)
    )


def validate_source(root: Path, relative: str, source: str) -> list[str]:
    """Return deterministic problems in one complete Python source blob."""
    if not relevant_python_path(relative):
        return []
    problems = ast_problems(source, relative)
    if not problems:
        problems.extend(lint_problems(root, relative, source))
    if not problems:
        formatting = formatting_problem(root, source)
        if formatting:
            problems.append(formatting)
    return problems


def _run_on_source(
    root: Path, source: str, *args: str, timeout: int = 60
) -> tuple[int, str]:
    """Give source text to a checker and return its complete result."""
    try:
        result = subprocess.run(
            args,
            cwd=str(root),
            input=source,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 124, "checker timed out"
    except FileNotFoundError:
        return 127, f"checker is unavailable: {args[0]}"
    return result.returncode, (result.stdout + result.stderr).strip()


def formatting_problem(root: Path, source: str) -> str | None:
    """Report Black formatting only when Black is installed."""
    code, output = _run_on_source(
        root, source, python_interpreter(root), "-m", "black", "--check", "-q", "-"
    )
    if code == 0:
        return None
    if code == 127 or "No module named black" in output:
        return None
    return output or "black: source is not formatted"


def lint_problems(root: Path, relative: str, source: str) -> list[str]:
    """Return Flake8 findings only when Flake8 is installed."""
    code, output = _run_on_source(
        root,
        source,
        python_interpreter(root),
        "-m",
        "flake8",
        "--stdin-display-name",
        relative,
        "-",
    )
    if code == 0 or code == 127 or "No module named flake8" in output:
        return []
    if code == 124:
        return [output]
    return [line.strip() for line in output.splitlines() if line.strip()]


def ast_problems(source: str, relative: str) -> list[str]:
    """Return every objective mandatory-rule violation in one Python file."""
    return (
        check_import_position(source, relative)
        + check_docstrings(source)
        + check_tbd_markers(source)
    )


def check_import_position(source: str, relative: str) -> list[str]:
    """Require every import to be in the module's opening import block."""
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        return [f"syntax error at line {exc.lineno}: {exc.msg}"]

    problems: list[str] = []
    import_block_open = True
    for index, node in enumerate(tree.body):
        module_docstring = (
            index == 0
            and isinstance(node, ast.Expr)
            and isinstance(node.value, ast.Constant)
            and isinstance(node.value.value, str)
        )
        if module_docstring:
            continue
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            if not import_block_open:
                problems.append(
                    f"line {node.lineno}: import below code; move it to the top of {relative}"
                )
            continue
        import_block_open = False

    for parent in ast.walk(tree):
        if not isinstance(
            parent, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
        ):
            continue
        for node in ast.walk(parent):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                problems.append(
                    f"line {node.lineno}: import inside '{parent.name}'; imports belong at module top"
                )

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.Try)) and any(
            isinstance(child, (ast.Import, ast.ImportFrom)) for child in ast.walk(node)
        ):
            problems.append(
                f"line {node.lineno}: conditional import; imports must be direct module-top statements"
            )
    return sorted(set(problems))


def check_docstrings(source: str) -> list[str]:
    """Require a useful documentation string on every named function."""
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return []
    problems: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        docstring = ast.get_docstring(node)
        if not docstring:
            problems.append(
                f"line {node.lineno}: '{node.name}' has no documentation string"
            )
        elif len(docstring.split()) < MIN_DOCSTRING_WORDS:
            problems.append(
                f"line {node.lineno}: '{node.name}' documentation is too short for plain-language meaning"
            )
    return problems


def check_tbd_markers(source: str) -> list[str]:
    """Require exact wording for TBD markers in source comments."""
    problems: list[str] = []
    try:
        tokens = tokenize.generate_tokens(io.StringIO(source).readline)
        comments = [token for token in tokens if token.type == tokenize.COMMENT]
    except tokenize.TokenError:
        return []
    for token in comments:
        if not TBD_PATTERN.search(token.string):
            continue
        if MAINTAINABILITY_TBD.search(token.string) or SINGLE_SOURCE_TBD.search(
            token.string
        ):
            continue
        problems.append(
            f"line {token.start[0]}: unsupported TBD; use exactly "
            "'TBD - maintainability and scalability: <reason>' or "
            "'TBD - one source of <thing>: <reason>' when that rule applies"
        )
    return problems
