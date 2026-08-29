---
paths:
  - "app/**/*.py"
  - "serverless/**/*.py"
  - "src/**/*.py"
  - "workers/**/*.py"
  - "tools/**/*.py"
  - "scripts/**/*.py"
  - "tests/**/*.py"
---

# Coding standards (rule 2)

## 2.1 Function documentation

Every function and method has a very short documentation string. Use wording a
non-technical person understands. Explain each technical term immediately in
parentheses.

The checker enforces presence and a small minimum. The independent review
judges brevity, wording, and explanations.

## 2.2 Implementation comments

Add very short comments for every relevant implementation step. Every relevant
call to an outer function or external service has a comment explaining why it
is called and what failure means. Comments explain decisions, not visible
syntax.

## 2.3 Maintainability and scalability

Follow both. If the correct approach materially increases implementation time,
ask the user to implement now or defer before writing dependent code.

An approved deferral uses exactly:

```text
TBD - maintainability and scalability: <reason>
```

## 2.4 Constants, enums, and one source

Constants and enum values have one appropriate source in configuration or the
database. Ask the user when the correct source is a material decision. If the
correct approach materially increases implementation time, ask whether to
implement now or defer.

An approved deferral uses exactly:

```text
TBD - one source of <thing>: <reason>
```

## 2.5 Imports

Every import is a direct module-top statement in the opening import block.
Never put an import inside a function, class, condition, exception block, or
after implementation code.

## Existing violations

When a file is altered, its complete current content must comply. Existing
project debt is not evidence that an incorrect practice may be preserved.
