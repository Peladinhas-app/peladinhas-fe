---
paths:
  - "app/api/**/*.py"
  - "app/services/**/*.py"
  - "app/repositories/**/*.py"
---

# API architecture

Full detail: `.github/instructions/architecture.instructions.md` and the
"Adding New Endpoints" section of `CONTRIBUTING.md`. Both remain the source.

## Vertical slice, always

New endpoints go in `app/api/<area>/<domain>/`:

```
app/api/<area>/<domain>/
├── routes.py       # HTTP only, zero business logic
├── service.py      # business logic, framework-agnostic
├── schemas.py      # request/response validation
└── tests/
```

Areas and their auth: `client/` (end-user JWT), `supplier/` (supplier JWT),
`internal/` (INTERNAL_API_KEY), `admin/` (admin JWT), `shared/` (varies).

## Rules

1. Routes are thin. No business logic, no queries.
2. Services never import `request` or `jsonify`. If a service needs the
   request, the boundary is in the wrong place.
3. Tests live inside the domain, not in a distant `tests/` mirror.
4. Roughly 300 lines per file. Past that, split by responsibility.

## The legacy trap

`app/api/invoices.py` and its flat siblings predate this layout. **Do not add
to them.** Matching the surrounding style there is precisely the
pattern-copying rule 5 prohibits — the surrounding style is the thing being
migrated away from.

Touching legacy code for an unrelated fix does not oblige you to migrate it.
Adding *new* endpoints to it is not acceptable.
