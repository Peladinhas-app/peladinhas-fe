# Git workflow (rule 6)

Claude stages and commits each coherent implementation step on the dedicated
task branch. A coherent step is independently understandable and testable;
avoid both one giant final commit and noisy commits for incomplete edits.

Each commit has exactly one concern. Never mix functional behavior with
refactoring, renaming, formatting, dependency maintenance, or unrelated cleanup.
Make behavior-preserving refactors and cleanup separate commits before or after
the functional change. Tests and documentation that directly prove or explain
that one concern belong with it; unrelated test or documentation cleanup does
not. Do not hide drive-by changes inside an otherwise valid commit.

Recent Codex commits are working history, not a declaration that the task is
final. Inspect them at the start of every turn and amend or follow them with an
improvement commit when new evidence requires it.

At task start, fetch `origin/staging` and integrate it before implementation.
At completion, fetch and integrate `origin/staging` again, then run the complete
standard suite on a clean HEAD. Fix every failure, including failures inherited
from staging. The completion hook records that exact HEAD; push approval fetches
and runs the suite again, and pre-push rejects any later staging or HEAD change.

Never push without user confirmation. Only the exact response `APPROVE PUSH`
creates a ten-minute, one-use approval bound to the repository, worktree,
branch, and HEAD. Any new commit, branch change, expiry, or reuse blocks push.

Codex configuration make the sandbox mandatory. Local hooks enforce
worktree, branch, secret-scan, message, and push-approval checks. They remain an
advisory boundary; remote branch protection and required CI are still required.

Commit and pull-request text is professional, impersonal, plain English. Never
address the reader directly, use emoji, or mention an assistant, model,
generator, or automated authorship. Branch names follow the same neutral rule
and use `<type>/<lowercase-task>` without tool or assistant prefixes. Both
message types use two levels of detail:

- Commit: `<type>(<scope>): <description>` under 72 characters, then a blank
  line, `Details:`, and no more than 100 words of necessary context.
- Pull request: a Conventional Commit title under 72 characters, then
  `## Summary` with no more than 30 words and `## Details` with no more than
  160 words covering relevant behavior, reason, risk, and validation.

Allowed types are `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`,
`ci`, `build`, and `style`. The commit hook and PR Message check enforce the
mechanical structure; the semantic review enforces clarity and relevance.
The pre-push hook rechecks the destination branch and every new commit being
transmitted. Git pushes have no separate message; their branch, commits, and
pull request carry the reviewed description.

Never push directly to `master` or `staging`, force-push without
`--force-with-lease`, or delete either protected branch.
