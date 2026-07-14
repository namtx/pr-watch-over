#!/usr/bin/env bash
set -euo pipefail

# Single-shot CI check monitor for a PR.
# Runs gh pr checks --json once, emits event, exits.

PR_NUMBER=""
REPO=""
JSON_FIELDS="name,state,bucket,link"

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
  echo "Usage: ci-monitor.sh <pr-number> [--repo owner/repo]" >&2
  exit 3
fi

GH_ARGS=("pr" "checks" "$PR_NUMBER" "--json" "$JSON_FIELDS")
if [[ -n "$REPO" ]]; then
  GH_ARGS+=(-R "$REPO")
fi

OUTPUT=$(gh "${GH_ARGS[@]}" 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 8 ]]; then
  echo "[ci:pending] checks still running for PR #$PR_NUMBER"
  exit 2
fi

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "[ci:error] gh exited $EXIT_CODE: $OUTPUT" >&2
  exit $EXIT_CODE
fi

# Parse JSON output
echo "$OUTPUT" | jq -c '.[]' | while read -r check; do
  name=$(echo "$check" | jq -r '.name')
  bucket=$(echo "$check" | jq -r '.bucket')
  link=$(echo "$check" | jq -r '.link // empty')
  echo "[ci:check] name=$name state=$bucket link=$link"
done

# Determine overall result
ALL_PASS=$(echo "$OUTPUT" | jq '[.[] | select(.bucket != "pass")] | length == 0')
ANY_FAIL=$(echo "$OUTPUT" | jq '[.[] | select(.bucket == "fail")] | length > 0')

if [[ "$ALL_PASS" == "true" ]]; then
  echo "[ci:pass] all checks passed for PR #$PR_NUMBER"
  exit 0
elif [[ "$ANY_FAIL" == "true" ]]; then
  FAILED_NAMES=$(echo "$OUTPUT" | jq -r '[.[] | select(.bucket == "fail") | .name] | join(", ")')
  echo "[ci:fail] checks failed for PR #$PR_NUMBER: $FAILED_NAMES"
  exit 1
else
  echo "[ci:pending] checks not yet resolved for PR #$PR_NUMBER"
  exit 2
fi
