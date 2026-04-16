#!/usr/bin/env bash
# Address new review comments on an auto-opened PR.
# Usage: handle-pr-comments.sh <pr_number>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PR="${1:?pr number required}"
is_numeric "$PR" || die "pr-comments: pr id must be numeric, got: $PR"
STATE_FILE="$(state_file_for_pr "$PR")"

cd "$REPO_ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
  log "pr-comments: repo has uncommitted changes, skipping PR #$PR"
  exit 1
fi

log "pr-comments: fetching PR #$PR"
PR_JSON="$(gh pr view "$PR" --json number,headRefName,state,isDraft,labels)"
STATE="$(echo "$PR_JSON" | jq -r '.state')"
if [[ "$STATE" != "OPEN" ]]; then
  log "pr-comments: PR #$PR is $STATE, skipping"
  exit 0
fi

LABELS_JSON="$(echo "$PR_JSON" | jq -c '.labels')"
if has_skip_label "$LABELS_JSON" "${SKIP_PR_LABELS[@]}"; then
  log "pr-comments: PR #$PR has a skip label, ignoring"
  exit 0
fi

BRANCH="$(echo "$PR_JSON" | jq -r '.headRefName')"
if [[ "$BRANCH" != ${AUTO_BRANCH_PREFIX}* ]]; then
  log "pr-comments: PR #$PR not on an auto branch, skipping"
  exit 0
fi

# Pull review + issue comments, filter by those newer than last_seen.
LAST_SEEN="$(get_state_kv "$STATE_FILE" last_seen_comment_id)"
LAST_SEEN="${LAST_SEEN:-0}"

COMMENTS_JSON="$(gh pr view "$PR" --json comments,reviews | \
  jq --argjson since "$LAST_SEEN" '
    [ (.comments // [])[]   | select(.id > $since) | {id, author: .author.login, body} ] +
    [ (.reviews  // [])[]   | select(.id > $since) | {id, author: .author.login, body: (.body // "(review submitted, no body)")} ]
    | sort_by(.id)
  ')"

COUNT="$(echo "$COMMENTS_JSON" | jq 'length')"
if [[ "$COUNT" -eq 0 ]]; then
  log "pr-comments: no new comments on PR #$PR"
  exit 0
fi

# Don't loop on our own comments (repo user).
SELF="$(gh api user --jq '.login')"
FILTERED="$(echo "$COMMENTS_JSON" | jq --arg self "$SELF" '[.[] | select(.author != $self and (.body | length) > 0)]')"
FCOUNT="$(echo "$FILTERED" | jq 'length')"
MAX_ID="$(echo "$COMMENTS_JSON" | jq 'map(.id) | max')"

if [[ "$FCOUNT" -eq 0 ]]; then
  log "pr-comments: no actionable comments on PR #$PR"
  write_state_kv "$STATE_FILE" last_seen_comment_id "$MAX_ID"
  exit 0
fi

COMMENTS_TEXT="$(echo "$FILTERED" | jq -r '.[] | "@\(.author): \(.body)\n"')"

log "pr-comments: checking out $BRANCH"
git fetch origin --quiet
git checkout "$BRANCH" --quiet
git pull --ff-only origin "$BRANCH" --quiet

BEFORE_SHA="$(git rev-parse HEAD)"

PROMPT="$(cat "$PROMPTS_DIR/pr-comments.md")"
PROMPT="${PROMPT//\{\{PR_NUMBER\}\}/$PR}"
PROMPT="${PROMPT//\{\{COMMENTS\}\}/$COMMENTS_TEXT}"

log "pr-comments: invoking Claude for PR #$PR"
set +e
RESPONSE="$(claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
  --disallowedTools "WebFetch,WebSearch" \
  --output-format text \
  --max-budget-usd 3.00 \
  --no-session-persistence 2>&1)"
CLAUDE_EXIT=$?
set -e

echo "$RESPONSE" | tail -20

if echo "$RESPONSE" | grep -q '^BLOCKED:'; then
  log "pr-comments: BLOCKED on PR #$PR; leaving state unchanged"
  git checkout main --quiet
  exit 1
fi

if [[ "$CLAUDE_EXIT" -ne 0 ]]; then
  log "pr-comments: claude exited $CLAUDE_EXIT; leaving state unchanged"
  git checkout main --quiet
  exit 1
fi

AFTER_SHA="$(git rev-parse HEAD)"
if [[ "$BEFORE_SHA" != "$AFTER_SHA" ]]; then
  git push origin "$BRANCH" --quiet
  log "pr-comments: pushed updates to $BRANCH"
else
  log "pr-comments: no changes were made"
fi

write_state_kv "$STATE_FILE" last_seen_comment_id "$MAX_ID"
git checkout main --quiet
