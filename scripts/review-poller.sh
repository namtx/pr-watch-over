#!/usr/bin/env bash
set -euo pipefail

# Single-shot review state poller for a PR.
# Runs gh pr view --json reviewDecision,latestReviews once, emits event, exits.

PR_NUMBER=""
REPO=""
JSON_FIELDS="reviewDecision,latestReviews"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|-R)
      REPO="$2"; shift 2 ;;
    --*)
      shift ;;
    *)
      PR_NUMBER="$1"; shift ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: review-poller.sh <pr-number> [--repo owner/repo]" >&2
  exit 3
fi

GH_ARGS=("pr" "view" "$PR_NUMBER" "--json" "$JSON_FIELDS")
if [[ -n "$REPO" ]]; then
  GH_ARGS+=(-R "$REPO")
fi

OUTPUT=$(gh "${GH_ARGS[@]}" 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "[review:error] gh exited $EXIT_CODE: $OUTPUT" >&2
  exit $EXIT_CODE
fi

DECISION=$(echo "$OUTPUT" | jq -r '.reviewDecision // "PENDING"')

case "$DECISION" in
  APPROVED)
    echo "[review:approved] PR #$PR_NUMBER approved"
    exit 0
    ;;
  CHANGES_REQUESTED)
    AUTHOR=$(echo "$OUTPUT" | jq -r '.latestReviews[0].author.login // "unknown"')
    BODY=$(echo "$OUTPUT" | jq -r '.latestReviews[0].body // ""' | head -c 200)
    echo "[review:changes_requested] PR #$PR_NUMBER author=$AUTHOR body=$BODY"
    exit 1
    ;;
  REVIEW_REQUIRED)
    echo "[review:pending] PR #$PR_NUMBER awaiting review"
    exit 2
    ;;
  PENDING)
    # Check if there are comment-only reviews
    COMMENT_COUNT=$(echo "$OUTPUT" | jq '[.latestReviews[] | select(.state == "COMMENTED")] | length')
    if [[ "$COMMENT_COUNT" -gt 0 ]]; then
      echo "[review:commented] PR #$PR_NUMBER has $COMMENT_COUNT comment(s)"
    else
      echo "[review:pending] PR #$PR_NUMBER no review yet"
    fi
    exit 2
    ;;
  *)
    echo "[review:pending] PR #$PR_NUMBER decision=$DECISION"
    exit 2
    ;;
esac
