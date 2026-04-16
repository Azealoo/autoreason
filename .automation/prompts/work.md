You are implementing GitHub issue #{{ISSUE_NUMBER}} in the current repository.

Follow the repository's CLAUDE.md principles strictly:
- Think before coding.
- Simplicity first — no unrequested abstractions.
- Surgical changes only.
- Every action maps to the stated goal.

Your task:
1. Read CLAUDE.md and any relevant existing code.
2. Implement the change requested in the issue below.
3. Stage and commit your changes on the current branch with a conventional-commit message (feat/fix/refactor/test/docs/chore) under 70 chars. Reference the issue in the body: "Refs #{{ISSUE_NUMBER}}".
4. Do NOT push. Do NOT open a PR. The surrounding script handles that.
5. Do NOT modify files under .automation/ or .github/ unless the issue explicitly asks for it.
6. If the issue is unclear once you start, STOP, commit nothing, and print a single line: "BLOCKED: <reason>".

--- ISSUE #{{ISSUE_NUMBER}} ---
TITLE: {{TITLE}}
LABELS: {{LABELS}}

BODY:
{{BODY}}
--- END ISSUE ---
