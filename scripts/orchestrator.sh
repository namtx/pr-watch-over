#!/usr/bin/env bash
set -euo pipefail

# Orchestrator for pr-watch-over skill.
# Runs single-shot CI check + review poll, emits events, exits.
# Claude Code calls this, interprets exit code, takes action, loops back.

PR_NUMBER=""
REPO=""
ROUND=1
MAX_ROUNDS=3
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|-R)
      REPO="$2"; shift 2 ;;
    --round)
      ROUND="$2"; shift 2 ;;
    --max-rounds)
      MAX_ROUNDS="$2"; shift 2 ;;
    --*)
      shift ;;
    *)
      PR_NUMBER="$1"; shift ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: orchestrator.sh <pr-number> [--repo owner/repo] [--round N] [--max-rounds N]" >&2
  exit 6
fi

echo "[info] round=$ROUND max=$MAX_ROUNDS PR=#$PR_NUMBER repo=${REPO:-default}"

if [[ "$ROUND" -gt "$MAX_ROUNDS" ]]; then
  echo "[escalate] max rounds ($MAX_ROUNDS) exhausted for PR #$PR_NUMBER"
  exit 4
fi

# Run CI check
if [[ -n "$REPO" ]]; then
  CI_OUTPUT=$(bash "$SCRIPT_DIR/ci-monitor.sh" "$PR_NUMBER" -R "$REPO" 2>&1) || CI_EXIT=$?
else
  CI_OUTPUT=$(bash "$SCRIPT_DIR/ci-monitor.sh" "$PR_NUMBER" 2>&1) || CI_EXIT=$?
fi
CI_EXIT=${CI_EXIT:-0}
echo "$CI_OUTPUT" | grep -E '^\[ci:' || true

# Check if PR is merged/closed
PR_STATE_OUTPUT=""
if [[ -n "$REPO" ]]; then
  PR_STATE_OUTPUT=$(gh pr view "$PR_NUMBER" --json state -R "$REPO" 2>/dev/null || echo "{}")
else
  PR_STATE_OUTPUT=$(gh pr view "$PR_NUMBER" --json state 2>/dev/null || echo "{}")
fi
PR_STATE=$(echo "$PR_STATE_OUTPUT" | jq -r '.state // "OPEN"')
if [[ "$PR_STATE" != "OPEN" ]]; then
  echo "[terminal] PR #$PR_NUMBER state=$PR_STATE"
  exit 0
fi

# Run review poller
if [[ -n "$REPO" ]]; then
  RV_OUTPUT=$(bash "$SCRIPT_DIR/review-poller.sh" "$PR_NUMBER" -R "$REPO" 2>&1) || RV_EXIT=$?
else
  RV_OUTPUT=$(bash "$SCRIPT_DIR/review-poller.sh" "$PR_NUMBER" 2>&1) || RV_EXIT=$?
fi
RV_EXIT=${RV_EXIT:-0}
echo "$RV_OUTPUT" | grep -E '^\[review:' || true

# Exit priority: fail > changes_requested > pending > pass+approved
if [[ "$CI_EXIT" -eq 1 ]]; then
  echo "[ci:fail] CI failed for PR #$PR_NUMBER"
  exit 1
fi

if [[ "$RV_EXIT" -eq 1 ]]; then
  echo "[review:changes_requested] changes requested for PR #$PR_NUMBER"
  exit 2
fi

if [[ "$CI_EXIT" -eq 2 ]] || [[ "$RV_EXIT" -eq 2 ]]; then
  echo "[waiting] PR #$PR_NUMBER not yet ready (CI pending or review pending)"
  exit 3
fi

echo "[done] PR #$PR_NUMBER all checks pass and approved"
exit 0
