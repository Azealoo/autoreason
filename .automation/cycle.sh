#!/usr/bin/env bash
# One iteration of the workflow loop. Called by systemd timer every 15 min.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOG_FILE="$LOG_DIR/cycle-$(date '+%Y%m%d').log"
exec >> "$LOG_FILE" 2>&1

find "$LOG_DIR" -name 'cycle-*.log' -mtime +30 -delete 2>/dev/null || true

log "========== cycle start =========="

if paused; then
  log "PAUSE file present; exiting"
  exit 0
fi

acquire_lock

cd "$REPO_ROOT"

# 1. Issues: classify new ones, work on the one most recently marked ready.
log "step 1: listing open issues assigned to @me"
ISSUES_JSON="$(gh issue list --state open --assignee @me --limit 50 --json number,updatedAt,labels)"
while read -r row; do
  NUM="$(echo "$row" | jq -r '.number')"
  UPDATED="$(echo "$row" | jq -r '.updatedAt')"
  STATE_FILE="$(state_file_for_issue "$NUM")"
  CURRENT="$(get_state_kv "$STATE_FILE" status)"
  LAST_UPDATED="$(get_state_kv "$STATE_FILE" last_issue_updated)"

  case "$CURRENT" in
    ready|pr_opened)
      # handled by later steps
      ;;
    blocked|skipped|closed|failed|no_change)
      # terminal unless the issue body was edited
      if [[ "$UPDATED" != "$LAST_UPDATED" ]]; then
        log "issue #$NUM was edited since '$CURRENT'; re-classifying"
        "$AUTO_ROOT/classify-issue.sh" "$NUM" || true
      fi
      ;;
    needs_info)
      if [[ "$UPDATED" != "$LAST_UPDATED" ]]; then
        log "issue #$NUM updated after needs_info; re-classifying"
        "$AUTO_ROOT/classify-issue.sh" "$NUM" || true
      fi
      ;;
    *)
      log "issue #$NUM: new, classifying"
      "$AUTO_ROOT/classify-issue.sh" "$NUM" || true
      ;;
  esac
done < <(echo "$ISSUES_JSON" | jq -c '.[]')

# 2. Pick one 'ready' issue to implement this cycle.
READY_ISSUE=""
for f in "$STATE_DIR"/issue-*.state; do
  [[ -f "$f" ]] || continue
  STATUS="$(get_state_kv "$f" status)"
  if [[ "$STATUS" == "ready" ]]; then
    READY_ISSUE="$(basename "$f" .state | sed 's/^issue-//')"
    break
  fi
done

if [[ -n "$READY_ISSUE" ]]; then
  log "step 2: working on issue #$READY_ISSUE"
  "$AUTO_ROOT/work-on-issue.sh" "$READY_ISSUE" || log "work-on-issue exited nonzero"
else
  log "step 2: no ready issues"
fi

# 3. Handle PR comments on open auto-PRs.
log "step 3: scanning open auto-PRs"
while read -r row; do
  PR="$(echo "$row" | jq -r '.number')"
  log "checking PR #$PR"
  "$AUTO_ROOT/handle-pr-comments.sh" "$PR" || log "handle-pr-comments exited nonzero for #$PR"
done < <(gh pr list --state open --limit 30 --json number,headRefName,isDraft \
  | jq -c --arg prefix "$AUTO_BRANCH_PREFIX" '.[] | select(.headRefName | startswith($prefix))')

log "========== cycle end =========="
