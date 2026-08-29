# Planning, contradictions, and doubts (rules 1, 3, 5)

## Before you implement (rule 5)

Every change gets evaluated against all of these. Not a checklist to recite —
a set of questions whose answers change the design:

| Dimension | The question |
|---|---|
| Correctness | What input makes this wrong? Which edge case is unhandled? |
| Maintainability | Who changes this in six months, and what will confuse them? |
| Scalability | What breaks at 10x rows, 10x requests, 10x file size? |
| Architecture | Does this belong in this layer, or is it here for convenience? |
| Duplication | Does this already exist? Search before writing. |
| Performance | What is the hot path, and what does this add to it? |
| Security | Untrusted input, credentials, authz boundaries — if relevant. |

**Existing patterns are evidence, not justification.** The surrounding code
shows what was done, not what is right. When you follow a pattern, say why it
fits here. When you depart, say why. Copying without that judgement violates
rule 5 even when the result works.

Specific to this repo: much of `app/` predates the vertical-slice layout in
`CONTRIBUTING.md`. Matching a legacy flat file is usually the wrong call.

## Agreeing the plan before building (rule 5)

Rule 5's evaluation happens in your head. For anything material that is not
enough: the reasoning has to be agreed *before* the work exists, not explained
after it.

For a material change, call `Codex planning mode`, present the approach, and wait
for approval. That approval is a real action the user takes, which is why it
is the mechanism — not a sentence in the transcript that could be read either
way.

**Material — align first:**

| Trigger | Why it earns an interruption |
|---|---|
| Database schema, `migrations/` | Hard to reverse once applied |
| Invoice or tariff calculation | Wrong numbers reach customers |
| Anything changing persisted data | Corruption outlives the session |
| Public API contract | Breaks callers you cannot see |
| A new dependency | Supply chain, licensing, permanence |
| New architectural pattern or top-level module | Sets precedent others copy |
| Cross-cutting refactor | Wide blast radius, hard to review |
| Deleting or rewriting existing behaviour | Loses knowledge nobody wrote down |

**Not material — decide, state it, continue:** a fix inside one function,
tests, documentation, formatting, a helper in an existing module, config
tweaks, anything reversible in one commit and obvious in review.

The trigger is **stakes, not certainty**. Being unsure is rule 3. Being sure
about something expensive to undo is this rule, and confidence is not grounds
to skip it — a confidently wrong architecture is exactly the failure this
catches.

Judgement, honestly: no hook can tell whether a plan was agreed. The
independent reviewer flags a material diff that shows no sign of prior
alignment, and that is the whole of the mechanical enforcement.

## Contradictions (rule 1)

Stop and ask when instructions conflict in a way that changes the output —
between the prompt and `CLAUDE.md`, between the prompt and existing code, or
inside the prompt itself.

State both readings and what each would produce. Do not pick one and mention
it afterwards.

Not a contradiction: an underspecified detail with an obvious standard answer.
Choose it, say what you chose, keep going.

## Doubts (rule 3)

Ask before implementing when the answer changes implementation, architecture,
behaviour, or data — especially anything touching persisted data or a public
contract.

Do not ask about: naming, formatting, which helper to use, or anything already
settled by this file. Decide, state the assumption, continue.

Timing matters. Do everything that does not depend on the answer first, then
ask once, with the question at the point where it actually blocks you.

## Deferring (rule 2.3, 2.4)

Deferring a maintainability or scalability concern needs the user's agreement.
Once agreed, mark it in the code:

```python
# TBD - maintainability and scalability: loads the whole invoice set into memory; fine under ~5k,
# needs pagination beyond that.
```

The exact wording is required. A one-source deferral instead uses
`TBD - one source of <thing>: <reason>`. Other TBD forms are rejected.
