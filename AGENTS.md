# peladinhas-fe — mandatory rules

## Rule loading

Before making changes, read and follow all applicable rules in:

- `.codex/rules/output-format.md`
- `.codex/rules/planning.md`
- `.codex/rules/worktree.md`
- `.codex/rules/architecture.md`
- `.codex/rules/git-workflow.md`
- `.codex/rules/trigger.md`
- `.codex/rules/coding-standards.md`

These rules are mandatory.

Seven rules, all mandatory. Hooks enforce mechanically whatever can be checked
mechanically; the rest is your judgement. Detail lives in `.codex/rules/`.
How the enforcement works: `docs/GOVERNANCE.md`.

## 1. Contradictions

When instructions conflict in a way that changes what gets built, stop and ask.
Do not silently pick one. Conflicts that do not change the outcome are not
worth raising.

## 2. Coding standards → `.codex/rules/coding-standards.md`

- **2.1** Every function gets a short docstring a non-technical reader can follow.
- **2.2** Comment the relevant steps, and every external call.
- **2.3** Weigh maintainability and scalability. Ask before deferring either;
  if deferred, mark it `TBD - maintainability and scalability: <reason>`.
- **2.4** Constants and enums have exactly one source (config or DB). Ask where
  it belongs when it is not obvious. A deferral is
  `TBD - one source of <thing>: <reason>`.
- **2.5** Imports go at the top of the module. Never mid-file, never inside a
  function.

## 3. Doubts

Material uncertainty about behaviour, data, architecture, or scope: ask before
implementing, not after. Do not interrupt for decisions with an obvious
standard answer — make those and say what you chose.

## 4. Output format → `.codex/rules/output-format.md`

All responses must follow the mandatory communication rules defined in
`.codex/rules/output-format.md`.

Responses must always be succinct, clear, and understandable without specialist
knowledge. Substantial responses use the Detailed/Succint structure defined
there. Simple responses do not require those sections.

When repository work occurred, include branch, commit, and push status.


## 5. Critical planning

Before implementing, evaluate: correctness, maintainability, scalability,
architecture, duplication, performance, and security where it applies.

An existing pattern is evidence, not justification. When you follow one, say
why it is right *here*. When you depart from one, say why. Copying the
surrounding code without that judgement is a rule 5 violation even when the
result works.

**Material change: agree the plan first.** Call `Codex planning mode`, present the
approach, and wait for approval before building. Material means any of:

- database schema or `migrations/`
- invoice or tariff calculation, or anything else that changes persisted data
- a public API contract — a new endpoint, or a changed request/response shape
- a new dependency
- a new architectural pattern, or a new top-level module
- a cross-cutting refactor, or deleting/rewriting existing behaviour

Everything else — a fix inside one function, tests, docs, formatting, a helper
in an existing module, config tweaks — just do, and say what you chose.
Confidence is not a reason to skip alignment; being unsure is rule 3's job,
and this is about stakes, not doubt.

## 6. Git → `.codex/rules/git-workflow.md`

Commit every coherent, tested implementation step on the dedicated task
branch. Recent Codex commits remain editable working history and should be
amended or improved when later evidence warrants it.

Every commit has one concern. Functional behavior must not share a commit with
refactoring, renaming, formatting, dependency maintenance, or unrelated cleanup.
Commit behavior-preserving work separately; keep only directly related tests and
documentation with the change they validate or explain.

Before implementation, fetch and integrate `origin/staging`. Before declaring
the task ready or requesting a push, fetch and integrate it again, then run the
complete standard test suite. Failures inherited from staging still block
completion and must be fixed. The exact push approval repeats synchronization
and the full tests; approval never bypasses either gate.

Never push without explicit confirmation. The exact response `APPROVE PUSH`
authorises one push attempt for the current branch and HEAD for ten minutes.

Commit and PR messages follow `CONTRIBUTING.md`: a very short Conventional
Commit title followed by concise supporting detail. Wording is professional,
impersonal, plain English, never direct reader address or emoji.
Local Git hooks enforce the worktree, branch, secret-scan, commit-message, and
push-approval checks. Remote branch protection and required CI remain necessary
because a local process can bypass local hooks.

Commit-time semantic review intentionally examines only the staged diff. Rules
about contradiction handling, uncertainty, planning judgement, and final-answer
communication remain mandatory instructions but are not inferred from or
mechanically reviewed against the conversation transcript. Worktree, branch,
commit-message, secret, and push boundaries remain mechanically enforced.
The isolated Codex commit reviewer is the single semantic authority by design;
if it is unavailable or unauthenticated, the commit fails closed rather than
silently changing to a different reviewer.

## 7. Worktrees

Every implementation task uses one linked Git worktree and one task branch.
The main checkout is never edited. A worktree cannot be reused for a different
task branch, and two Codex tasks never share a working directory. Reuse the worktree created for the current Codex task; rename its temporary `codex/...` or `worktree-...` branch
before the first modification instead of creating a replacement worktree.

Governance maintenance happens only in a dedicated worktree on a branch whose
name contains `governance` and no assistant-identifying marker.

