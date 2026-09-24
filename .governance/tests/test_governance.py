"""Exercise governance boundaries in disposable Git repositories."""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


def clear_inherited_git_environment() -> None:
    """Detach disposable repositories from a parent Git hook repository."""
    result = subprocess.run(
        ["git", "rev-parse", "--local-env-vars"],
        capture_output=True,
        text=True,
        check=False,
    )
    for variable in (*result.stdout.splitlines(), "GIT_PREFIX"):
        os.environ.pop(variable, None)


clear_inherited_git_environment()

GOVERNANCE = Path(__file__).resolve().parents[1]
ROOT = GOVERNANCE.parent
sys.path.insert(0, str(GOVERNANCE))


def load(name: str, path: Path):
    """Load one module directly from its repository path."""
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


session = load("session", GOVERNANCE / "session.py")
approval = load("governance_approval", GOVERNANCE / "approval.py")
checks = load("governance_checks", GOVERNANCE / "checks.py")
commit_checks = load("governance_commit_checks", GOVERNANCE / "commit_checks.py")
commit_review = load("governance_commit_review", GOVERNANCE / "commit_review.py")
features = load("governance_features", GOVERNANCE / "features.py")
readiness = load("governance_readiness", GOVERNANCE / "readiness.py")
message_structure = load(
    "governance_messages", ROOT / ".githooks" / "message_structure.py"
)


def git(root: Path, *arguments: str) -> str:
    """Run Git in one disposable test repository."""
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


class TemporaryRepository(unittest.TestCase):
    """Provide a current protected checkout for each stateful test."""

    def setUp(self) -> None:
        """Create a repository whose main checkout is on main."""
        self.temporary = tempfile.TemporaryDirectory(prefix="governance-test-")
        self.root = Path(self.temporary.name).resolve() / "main"
        self.root.mkdir()
        git(self.root, "init", "-q")
        git(self.root, "config", "user.email", "governance@example.test")
        git(self.root, "config", "user.name", "Governance Test")
        (self.root / "base.txt").write_text("base\n", encoding="utf-8")
        (self.root / ".gitignore").write_text(".governance/state/\n", encoding="utf-8")
        git(self.root, "add", "base.txt", ".gitignore")
        git(self.root, "commit", "-qm", "chore: initialize")
        git(self.root, "branch", "-M", "main")
        git(self.root, "remote", "add", "origin", str(self.root))
        git(self.root, "fetch", "-q", "origin", "main")

    def make_worktree(self, branch: str = "fix/test-task") -> Path:
        """Create one final task branch and linked worktree."""
        linked = Path(self.temporary.name).resolve() / branch.replace("/", "-")
        git(self.root, "worktree", "add", "-qb", branch, str(linked), "HEAD")
        return linked

    def make_temporary_worktree(self) -> Path:
        """Create a recognized Codex temporary worktree."""
        return self.make_worktree("codex/desktop-task-abcdef")

    def advance_main(self) -> None:
        """Move main forward by one committed change."""
        (self.root / "base.txt").write_text("new base\n", encoding="utf-8")
        git(self.root, "add", "base.txt")
        git(self.root, "commit", "-qm", "fix: advance base")
        git(self.root, "fetch", "-q", "origin", "main")

    def tearDown(self) -> None:
        """Remove the disposable repository and all linked worktrees."""
        self.temporary.cleanup()


class SessionTests(TemporaryRepository):
    """Prove worktree, branch, and protected-path enforcement."""

    def test_main_checkout_rejected_and_worktree_accepted(self) -> None:
        """Reject main task work and accept a governed branch worktree."""
        with self.assertRaises(session.GovernanceStateError):
            session.validate_task_context(self.root)
        linked = self.make_worktree()
        session.validate_task_context(linked)

    def test_temporary_codex_branch_can_be_renamed(self) -> None:
        """Allow the exact temporary branch rename before modification."""
        linked = self.make_temporary_worktree()
        session.validate_temporary_rename(linked, "fix/desktop-task")

    def test_invalid_temporary_rename_is_rejected(self) -> None:
        """Reject protected, invalid, and dirty temporary renames."""
        linked = self.make_temporary_worktree()
        with self.assertRaises(session.GovernanceStateError):
            session.validate_temporary_rename(linked, "main")
        with self.assertRaises(session.GovernanceStateError):
            session.validate_temporary_rename(linked, "BadBranch")
        (linked / "base.txt").write_text("dirty\n", encoding="utf-8")
        with self.assertRaises(session.GovernanceStateError):
            session.validate_temporary_rename(linked, "fix/dirty-task")

    def test_task_binding_rejects_later_branch_switch(self) -> None:
        """Prevent one physical worktree from changing task identity."""
        linked = self.make_worktree()
        session.validate_task_context(linked)
        git(linked, "switch", "-qc", "fix/other-task")
        with self.assertRaises(session.GovernanceStateError):
            session.validate_task_context(linked)

    def test_governance_files_require_governance_branch(self) -> None:
        """Keep policy changes on an explicitly named governance branch."""
        linked = self.make_worktree("fix/ordinary-task")
        governed = self.make_worktree("chore/governance-task")
        self.assertTrue(session.protected_path(linked / ".governance/session.py", linked))
        self.assertFalse(session.governance_branch(linked))
        self.assertTrue(session.governance_branch(governed))


class ApprovalTests(TemporaryRepository):
    """Prove push approval binds the exact branch update and commit."""

    def setUp(self) -> None:
        """Create and bind one task worktree before each approval test."""
        super().setUp()
        self.linked = self.make_worktree()
        session.validate_task_context(self.linked)
        self.validation = mock.patch.object(
            approval.readiness,
            "validate_final",
            side_effect=lambda root, reuse_receipt: {
                "head": git(root, "rev-parse", "HEAD"),
                "main_head": git(root, "rev-parse", "origin/main"),
                "passed_at": 123,
            },
        )
        self.validation.start()
        self.addCleanup(self.validation.stop)

    def proposed_ref(self, remote: str = "fix/test-task") -> str:
        """Return one pre-push input line for the current task HEAD."""
        head = git(self.linked, "rev-parse", "HEAD")
        return f"refs/heads/fix/test-task {head} refs/heads/{remote} {'0' * 40}"

    def test_missing_approval_is_rejected(self) -> None:
        """Require the exact user-triggered token before a push."""
        self.assertFalse(approval.check_refs(self.linked, [self.proposed_ref()])[0])

    def test_exact_branch_and_head_are_accepted_once(self) -> None:
        """Accept one matching ref and reject it after consumption."""
        approval.issue(self.linked, "session-a")
        self.assertTrue(approval.check_refs(self.linked, [self.proposed_ref()])[0])
        self.assertTrue(approval.consume(self.linked))
        self.assertFalse(approval.check_refs(self.linked, [self.proposed_ref()])[0])

    def test_other_ref_head_or_multiple_updates_are_rejected(self) -> None:
        """Prevent one token from authorizing unrelated ref updates."""
        approval.issue(self.linked, "session-a")
        self.assertFalse(
            approval.check_refs(self.linked, [self.proposed_ref("fix/other-task")])[0]
        )
        wrong = self.proposed_ref().replace(
            git(self.linked, "rev-parse", "HEAD"), "1" * 40
        )
        self.assertFalse(approval.check_refs(self.linked, [wrong])[0])
        self.assertFalse(
            approval.check_refs(
                self.linked, [self.proposed_ref(), self.proposed_ref()]
            )[0]
        )

    def test_main_change_after_tests_invalidates_approval(self) -> None:
        """Require a new synchronization when main advances."""
        approval.issue(self.linked, "session-a")
        self.advance_main()
        allowed, reason = approval.check_refs(self.linked, [self.proposed_ref()])
        self.assertFalse(allowed)
        self.assertIn("origin/main changed", reason)


class MainBootstrapApprovalTests(TemporaryRepository):
    """Prove only the first empty-remote main creation can be approved."""

    def setUp(self) -> None:
        """Point origin at a bare remote that starts without branches."""
        super().setUp()
        self.remote = Path(self.temporary.name).resolve() / "origin.git"
        git(self.root, "init", "--bare", "-q", str(self.remote))
        git(self.root, "remote", "set-url", "origin", str(self.remote))
        self.checks = mock.patch.object(
            approval, "run_bootstrap_checks", return_value=(True, "ok")
        )
        self.checks_mock = self.checks.start()
        self.addCleanup(self.checks.stop)

    def bootstrap_ref(self, *, source: str = "refs/heads/main") -> str:
        """Return one proposed pre-push main-bootstrap update."""
        head = git(self.root, "rev-parse", "main")
        return f"{source} {head} refs/heads/main {'0' * 40}"

    def approve(self) -> None:
        """Issue the exact main-bootstrap approval for local main."""
        approval.issue_main_bootstrap(
            self.root, approval.BOOTSTRAP_APPROVAL_PHRASE
        )

    def test_empty_remote_with_valid_bootstrap_approval_is_allowed(self) -> None:
        """Accept the exact first remote-main creation."""
        self.approve()
        allowed, _ = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertTrue(allowed)

    def test_unchanged_remote_url_fingerprint_is_allowed(self) -> None:
        """Accept approval while the remote push URL is unchanged."""
        self.approve()
        token = json.loads(approval.bootstrap_state_path(self.root).read_text())
        self.assertEqual(
            token["remote_push_url_sha256"],
            approval.remote_push_url_fingerprint(self.root, "origin"),
        )
        self.assertTrue(
            approval.check_main_bootstrap_refs(self.root, [self.bootstrap_ref()])[0]
        )

    def test_no_approval_is_rejected(self) -> None:
        """Reject bootstrap when no deliberate approval was recorded."""
        allowed, _ = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)

    def test_wrong_approval_phrase_is_rejected(self) -> None:
        """Require the exact bootstrap approval phrase."""
        with self.assertRaises(RuntimeError):
            approval.issue_main_bootstrap(self.root, "APPROVE PUSH")

    def test_approval_for_another_commit_is_rejected(self) -> None:
        """Bind bootstrap approval to the exact local main commit."""
        self.approve()
        (self.root / "later.txt").write_text("later\n", encoding="utf-8")
        git(self.root, "add", "later.txt")
        git(self.root, "commit", "-qm", "chore: later main")
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)
        self.assertIn("another commit", reason)

    def test_dirty_worktree_is_rejected(self) -> None:
        """Require a clean local main worktree for bootstrap."""
        self.approve()
        (self.root / "dirty.txt").write_text("dirty\n", encoding="utf-8")
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)
        self.assertIn("clean worktree", reason)

    def test_multiple_pushed_refs_are_rejected(self) -> None:
        """Permit only one ref update during bootstrap."""
        self.approve()
        line = self.bootstrap_ref()
        self.assertFalse(approval.check_main_bootstrap_refs(self.root, [line, line])[0])

    def test_non_main_source_is_rejected(self) -> None:
        """Require local refs/heads/main as the pushed source."""
        self.approve()
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref(source="refs/heads/chore/task")]
        )
        self.assertFalse(allowed)
        self.assertIn("source", reason)

    def test_remote_main_already_exists_is_rejected(self) -> None:
        """Reject bootstrap after remote main exists."""
        git(self.root, "push", "-q", "origin", "main:refs/heads/main")
        with self.assertRaises(RuntimeError):
            self.approve()

    def test_remote_contains_another_branch_is_rejected(self) -> None:
        """Reject bootstrap when any remote branch already exists."""
        git(self.root, "push", "-q", "origin", "main:refs/heads/other")
        with self.assertRaises(RuntimeError):
            self.approve()

    def test_remote_lookup_failure_is_rejected(self) -> None:
        """Treat lookup and authentication failures as unsafe."""
        git(self.root, "remote", "set-url", "origin", str(self.remote / "missing"))
        with self.assertRaises(RuntimeError):
            self.approve()

    def test_repointing_origin_invalidates_approval(self) -> None:
        """Reject approval reuse after origin points to a different empty remote."""
        self.approve()
        other = Path(self.temporary.name).resolve() / "other.git"
        git(self.root, "init", "--bare", "-q", str(other))
        git(self.root, "remote", "set-url", "origin", str(other))
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)
        self.assertIn("remote URL", reason)

    def test_another_remote_name_with_different_url_cannot_reuse_approval(self) -> None:
        """Reject another remote name that points at a different URL."""
        self.approve()
        other = Path(self.temporary.name).resolve() / "other.git"
        git(self.root, "init", "--bare", "-q", str(other))
        git(self.root, "remote", "add", "backup", str(other))
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()], "backup"
        )
        self.assertFalse(allowed)
        self.assertIn("another remote", reason)

    def test_push_url_lookup_failure_during_validation_is_rejected(self) -> None:
        """Reject when the approved remote disappears before push."""
        self.approve()
        git(self.root, "remote", "remove", "origin")
        allowed, reason = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)
        self.assertIn("push URL", reason)

    def test_ordinary_direct_push_to_existing_main_remains_rejected(self) -> None:
        """Keep normal direct pushes to main forbidden after bootstrap."""
        git(self.root, "push", "-q", "origin", "main:refs/heads/main")
        head = git(self.root, "rev-parse", "main")
        line = f"refs/heads/main {head} refs/heads/main {head}"
        self.assertFalse(approval.check_main_bootstrap_refs(self.root, [line])[0])

    def test_secret_scan_failure_remains_blocking(self) -> None:
        """Reject bootstrap when the required checks fail."""
        self.checks_mock.return_value = (False, "secret scan failed")
        with self.assertRaises(RuntimeError):
            self.approve()

    def test_post_authorization_failure_consumes_approval(self) -> None:
        """Consume approval before later hook validation can fail."""
        self.approve()
        self.assertTrue(
            approval.check_main_bootstrap_refs(self.root, [self.bootstrap_ref()])[0]
        )
        self.assertTrue(approval.consume_main_bootstrap(self.root))
        allowed, _ = approval.check_main_bootstrap_refs(
            self.root, [self.bootstrap_ref()]
        )
        self.assertFalse(allowed)


class MainBootstrapHookIntegrationTests(unittest.TestCase):
    """Exercise the real pre-push hook against a local bare remote."""

    def setUp(self) -> None:
        """Create a repository with copied governance hooks."""
        self.temporary = tempfile.TemporaryDirectory(prefix="governance-hook-")
        self.root = Path(self.temporary.name).resolve() / "repo"
        self.remote = Path(self.temporary.name).resolve() / "origin.git"
        self.root.mkdir()
        git(self.root, "init", "-q")
        git(self.root, "config", "user.email", "governance@example.test")
        git(self.root, "config", "user.name", "Governance Test")
        git(self.root, "init", "--bare", "-q", str(self.remote))
        git(self.root, "remote", "add", "origin", str(self.remote))
        (self.root / ".gitignore").write_text("__pycache__/\n*.pyc\n", encoding="utf-8")
        self.copy_governance_files()

    def tearDown(self) -> None:
        """Remove the disposable hook repository."""
        self.temporary.cleanup()

    def copy_governance_files(self) -> None:
        """Copy real governance code while stubbing recursive tests."""
        shutil.copytree(
            ROOT / ".githooks",
            self.root / ".githooks",
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        )
        shutil.copytree(
            ROOT / ".governance",
            self.root / ".governance",
            ignore=shutil.ignore_patterns("state", "__pycache__", "*.pyc"),
        )
        tests = self.root / ".governance" / "tests"
        tests.mkdir(exist_ok=True)
        (tests / "test_governance.py").write_text(
            "import unittest\n\n"
            "class BootstrapFixtureTests(unittest.TestCase):\n"
            "    def test_ok(self):\n"
            "        self.assertTrue(True)\n\n"
            "if __name__ == '__main__':\n"
            "    unittest.main()\n",
            encoding="utf-8",
        )

    def run_git(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess:
        """Run Git in the integration repository."""
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=check,
        )

    def commit_file(self, name: str, content: str, *, valid_message: bool = True) -> str:
        """Create one local main commit and return its SHA."""
        (self.root / name).write_text(content, encoding="utf-8")
        self.run_git("add", name, ".gitignore", ".githooks", ".governance")
        if valid_message:
            self.run_git(
                "-c",
                "core.hooksPath=",
                "commit",
                "-qm",
                "chore(governance): update bootstrap fixture",
                "-m",
                "Details:",
                "-m",
                "Update the local hook integration fixture.",
            )
        else:
            self.run_git("-c", "core.hooksPath=", "commit", "-qm", "bad")
        self.run_git("branch", "-M", "main")
        return git(self.root, "rev-parse", "HEAD")

    def approve_bootstrap(self) -> subprocess.CompletedProcess:
        """Issue the exact bootstrap approval using the copied script."""
        result = subprocess.run(
            [
                sys.executable,
                ".governance/approval.py",
                "issue-main-bootstrap",
                approval.BOOTSTRAP_APPROVAL_PHRASE,
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        return result

    def test_first_real_main_push_succeeds_and_second_is_rejected(self) -> None:
        """Allow only the first approved main push through the real hook."""
        first = self.commit_file("base.txt", "base\n")
        self.run_git("config", "core.hooksPath", ".githooks")
        self.assertEqual("", git(self.root, "ls-remote", "--heads", "origin"))
        self.approve_bootstrap()

        self.run_git("push", "--set-upstream", "origin", "main")
        self.assertEqual(first, git(self.root, "rev-parse", "origin/main"))

        self.commit_file("later.txt", "later\n")
        rejected = self.run_git("push", "origin", "main", check=False)
        self.assertNotEqual(0, rejected.returncode)
        self.assertEqual(first, git(self.root, "rev-parse", "origin/main"))

    def test_post_authorization_hook_failure_consumes_approval(self) -> None:
        """Consume approval before a later hook validation failure exits."""
        self.commit_file("bad.txt", "bad\n", valid_message=False)
        self.run_git("config", "core.hooksPath", ".githooks")
        self.approve_bootstrap()

        rejected = self.run_git("push", "--set-upstream", "origin", "main", check=False)
        self.assertNotEqual(0, rejected.returncode)
        self.assertFalse(approval.bootstrap_state_path(self.root).exists())

        retry = self.run_git("push", "--set-upstream", "origin", "main", check=False)
        self.assertNotEqual(0, retry.returncode)
        self.assertEqual("", git(self.root, "ls-remote", "--heads", "origin"))


class CommitValidationTests(TemporaryRepository):
    """Validate staged-blob, message, review, and secret behavior."""

    def test_deterministic_checks_read_the_staged_blob(self) -> None:
        """Do not let a clean unstaged copy hide invalid staged source."""
        linked = self.make_worktree()
        source = linked / ".governance" / "example.py"
        source.parent.mkdir()
        source.write_text("def broken():\n    return 1\n", encoding="utf-8")
        git(linked, "add", ".governance/example.py")
        source.write_text(
            'def fixed():\n    """Return one fixed value."""\n    return 1\n',
            encoding="utf-8",
        )
        findings = commit_checks.check_files(linked, [".governance/example.py"])
        self.assertTrue(any("no documentation" in item for item in findings))
        self.assertEqual(
            [".governance/example.py"],
            commit_checks.partially_staged_paths(linked, [".governance/example.py"]),
        )

    def test_governance_changes_select_the_governance_suite(self) -> None:
        """Always run workflow tests when policy or hooks change."""
        self.assertIn(
            commit_checks.GOVERNANCE_TEST,
            commit_checks.related_tests(ROOT, [".governance/session.py"]),
        )

    def test_missing_flake8_is_not_required_for_this_frontend_repo(self) -> None:
        """Keep backend-only lint dependencies optional here."""
        self.assertEqual(
            [],
            checks.lint_problems(
                ROOT,
                ".governance/example.py",
                'def ok():\n    """Return one plain value."""\n    return 1\n',
            ),
        )

    def test_directory_test_targets_use_unittest_discovery(self) -> None:
        """Run discovered tests instead of executing a directory."""
        with tempfile.TemporaryDirectory(prefix="governance-test-target-") as directory:
            root = Path(directory)
            tests = root / "tests"
            tests.mkdir()
            (tests / "test_sample.py").write_text(
                "import unittest\n\n"
                "class SampleTests(unittest.TestCase):\n"
                "    def test_ok(self):\n"
                "        self.assertTrue(True)\n",
                encoding="utf-8",
            )
            self.assertIsNone(
                commit_checks.run_test_command(
                    root,
                    [sys.executable, "-m", "unittest", "discover", "tests"],
                )
            )

    def test_secret_scanner_rejects_staged_environment_file(self) -> None:
        """Exercise the scanner against a staged forbidden filename."""
        linked = self.make_worktree()
        scanner = ROOT / ".githooks" / "secret_scan.py"
        (linked / ".env").write_text("VALUE=not-a-secret\n", encoding="utf-8")
        git(linked, "add", ".env")
        result = subprocess.run(
            [sys.executable, str(scanner)],
            cwd=linked,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(0, result.returncode)

    def test_semantic_review_parses_strict_json_and_fails_closed(self) -> None:
        """Keep review strict while the reviewer integration is missing."""
        self.assertTrue(commit_review.parse_verdict('{"pass":true,"problems":[]}'))
        with self.assertRaises(RuntimeError):
            commit_review.parse_verdict('{"pass":false,"problems":[{"rule":1}]}')
        with self.assertRaises(RuntimeError):
            commit_review.run_review(ROOT, "prompt", "diff")

    def test_semantic_review_feature_is_disabled_until_verified(self) -> None:
        """Keep the unavailable reviewer documented but inactive."""
        self.assertFalse(features.enabled(ROOT, "semantic_commit_review"))

    def test_commit_message_structure_remains_enforced(self) -> None:
        """Accept the two-level format and reject subject-only text."""
        valid = (
            "fix(governance): validate change messages\n\n"
            "Details:\nEnforce concise professional commit text.\n"
        )
        self.assertEqual([], message_structure.validate_commit_message(valid))
        self.assertTrue(
            message_structure.validate_commit_message(
                "fix(governance): validate change messages\n"
            )
        )
        self.assertTrue(message_structure.branch_name_problems("codex/bad-branch"))


class ObjectiveRuleTests(unittest.TestCase):
    """Exercise deterministic source-code rules."""

    def test_functions_need_docstrings_and_imports_stay_at_top(self) -> None:
        """Reject undocumented functions and imports below executable code."""
        source = "x = 1\nimport os\n\ndef f():\n    return 1\n"
        self.assertTrue(checks.check_docstrings(source))
        self.assertTrue(checks.check_import_position(source, "probe.py"))

    def test_exact_tbd_forms_pass(self) -> None:
        """Accept only the two mandatory deferral forms."""
        valid = (
            "# TBD - maintainability and scalability: split after migration\n"
            "# TBD - one source of tariff truth: upstream API is pending\n"
        )
        self.assertEqual([], checks.check_tbd_markers(valid))
        self.assertTrue(checks.check_tbd_markers("# TBD: later\n"))


class ReadinessTests(TemporaryRepository):
    """Prove completion and approval use the current main revision."""

    def test_final_validation_fetches_and_runs_full_suite(self) -> None:
        """Record tests only for the exact clean HEAD and fetched main."""
        linked = self.make_worktree()
        session.validate_task_context(linked)
        with mock.patch.object(readiness, "run_full_tests") as full_tests:
            receipt = readiness.validate_final(linked, reuse_receipt=False)
        full_tests.assert_called_once_with(linked)
        self.assertEqual(git(linked, "rev-parse", "HEAD"), receipt["head"])
        self.assertEqual(git(linked, "rev-parse", "origin/main"), receipt["main_head"])

    def test_diverged_task_must_integrate_main(self) -> None:
        """Never rewrite existing task commits invisibly during startup."""
        linked = self.make_worktree()
        (linked / "task.txt").write_text("task\n", encoding="utf-8")
        git(linked, "add", "task.txt")
        git(linked, "commit", "-qm", "fix: task change")
        self.advance_main()
        with self.assertRaises(session.GovernanceStateError):
            readiness.synchronize_start(linked)

    def test_missing_remote_main_bootstraps_from_local_main(self) -> None:
        """Allow initial repositories before origin main exists."""
        linked = self.make_worktree()
        git(self.root, "update-ref", "-d", "refs/remotes/origin/main")
        self.assertEqual(git(self.root, "rev-parse", "main"), readiness.fetch_main(linked))


if __name__ == "__main__":
    unittest.main()
