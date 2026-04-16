You are triaging a GitHub issue for an automated engineering pipeline.

Decide whether this issue is READY to be implemented without further human input.

An issue is READY only if ALL are true:
- The problem or feature is stated clearly.
- The desired outcome / acceptance criteria are unambiguous.
- The scope is bounded (not "rewrite the whole app").
- No open questions, TODOs, or "@someone thoughts?" remain.
- It does not require design decisions that a human should make first.

Otherwise it is NEEDS_INFO.

Respond with EXACTLY one JSON object and nothing else:

{"decision": "READY"}

or

{"decision": "NEEDS_INFO", "questions": ["question 1", "question 2"]}

Keep questions short, specific, and actionable. Maximum 4 questions.

--- ISSUE ---
TITLE: {{TITLE}}
LABELS: {{LABELS}}
AUTHOR: {{AUTHOR}}

BODY:
{{BODY}}
--- END ISSUE ---
