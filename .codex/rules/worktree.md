# Task worktrees

Every implementation task uses one dedicated linked Git worktree and one task branch.

Reading, investigation, planning, and user questions may happen before the final task branch is established.

Codex Desktop may initially create a temporary `codex/...` or `worktree-...` branch. Before the first repository modification:

1. Determine the appropriate task type and concise task name.
2. Rename the temporary branch to `<type>/<lowercase-task>`.
3. Continue implementation only after the branch satisfies governance.

Supported task types are:
`feature`, `fix`, `hotfix`, `chore`, `docs`, `refactor`, `test`.

Never create a second worktree merely to replace a Codex Desktop-generated worktree.
