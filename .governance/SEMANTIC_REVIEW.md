# Semantic Review Integration

Semantic commit review is currently unavailable and disabled in
`.governance/governance.json`.

The original governance used a Claude-specific non-interactive command that
accepted a staged diff on standard input and returned strict JSON validated by
`commit_review.py`. No equivalent Codex or OpenAI command has been verified in
this repository yet.

The implementation in `.governance/commit_review.py` remains fail-closed. If the
feature is enabled before a verified reviewer is configured, governed commits
will be blocked instead of silently passing.

Enable the feature only after verifying a real non-interactive reviewer
invocation that:

- accepts the staged diff through standard input;
- disables tools, memory, and project instructions for the reviewer;
- constrains output to the schema used by `.governance/commit_review.py`;
- returns nonzero or invalid JSON on reviewer failure; and
- is covered by `.governance/tests/test_governance.py`.
