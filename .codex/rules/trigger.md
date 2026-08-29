---
paths:
  - "trigger/**"
  - "src/**/*.ts"
  - "**/*.trigger.ts"
  - "trigger.config.ts"
  - "trigger.staging.config.ts"
---

# Trigger.dev tasks

Full reference: **`AGENTS.md`** (1400 lines, kept as the single source). Read it
before writing a task. What follows is only the set of mistakes that break
production silently.

## Non-negotiable

- Import from **`@trigger.dev/sdk`** (v4). Never `@trigger.dev/sdk/v3`.
- Never `client.defineJob` — v2, removed. Use `task()` or `schemaTask()`.
- Every task is exported. An unexported task is invisible to the deploy.
- `triggerAndWait()` returns a **Result**, not your task's output. Check
  `result.ok` before touching `result.output`, or use `.unwrap()`.
- Never call `triggerAndWait()` inside a loop — batch it. Sequential waits
  burn concurrency slots and deadlock the queue.

## This repo

- Deploys are driven by `package.json` scripts (`deploy:dev`, `deploy:staging`,
  `deploy:prod`). Do not hand-roll a deploy command.
- Two configs exist: `trigger.config.ts` and `trigger.staging.config.ts`.
  Check which environment a change targets before editing either.
- Tests run under vitest (`npm test`), not pytest.
