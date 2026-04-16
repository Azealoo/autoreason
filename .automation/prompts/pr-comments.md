You are addressing reviewer feedback on pull request #{{PR_NUMBER}}.

Follow the repository's CLAUDE.md principles (Think / Simplicity / Surgical / Goal-Driven).

Your task:
1. Read the new review comments below.
2. Make the minimum changes needed to address them. Do not refactor surrounding code.
3. Commit on the current branch with message: "fix: address PR review feedback (PR #{{PR_NUMBER}})".
4. Do NOT push. The surrounding script handles that.
5. If a comment is ambiguous or asks for a design decision, STOP and print a single line:
   "BLOCKED: <which comment, what question>".

--- NEW REVIEW COMMENTS ---
{{COMMENTS}}
--- END COMMENTS ---
