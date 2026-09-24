# Initial `origin/main` bootstrap

Direct pushes to remote `main` remain forbidden after the first remote branch is
created. The only exception is an empty-remote bootstrap for a repository whose
remote has no branch heads yet.

## Approval

From a clean local `main` checkout, record the one-use bootstrap approval:

```powershell
python .governance/approval.py issue-main-bootstrap "APPROVE MAIN BOOTSTRAP"
```

The approval is stored under Git's private directory, is bound to the exact
local `main` commit and remote push URL fingerprint, and becomes ineffective
once the remote has any branch.

## Push

Immediately after approval, create the first remote `main` branch:

```powershell
git push --set-upstream origin main
```

The pre-push hook allows this only when the push creates `refs/heads/main` from
the zero SHA, contains exactly one ref update, starts from local `main`, the
worktree is clean, live remote inspection finds no branch heads, and governance
checks pass. The approval is consumed immediately after those bootstrap
authorization checks pass, before later validation runs. If a later validation
step fails, issue a fresh approval before retrying. Any later direct push to
remote `main` is rejected.
