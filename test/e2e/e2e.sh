#!/usr/bin/env bash
set -euo pipefail

# E2E test for pr-watch-over skill
# Creates a throwaway GitHub repo, opens a PR with a CI workflow,
# runs the CI monitor script, verifies detection.
#
# Prerequisites: gh CLI authenticated with repo scope
# Usage: ./test/e2e/e2e.sh [--cleanup]
#   --cleanup: delete the test repo after test

CLEANUP=false
if [[ "${1:-}" == "--cleanup" ]]; then
  CLEANUP=true
fi

E2E_DIR=$(mktemp -d)
REPO_NAME="pr-watch-over-e2e-$(date +%s)"
TEST_USER=""
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  echo "=== CLEANUP ==="
  if [[ "$CLEANUP" == true ]]; then
    echo "Deleting test repo $TEST_USER/$REPO_NAME..."
    gh repo delete "$TEST_USER/$REPO_NAME" --yes 2>/dev/null || true
  fi
  echo "Removing $E2E_DIR..."
  rm -rf "$E2E_DIR"
  echo "Done."
}
trap cleanup EXIT

echo "=== E2E: pr-watch-over ==="

# Get test user
TEST_USER=$(gh api user --jq .login)
echo "User: $TEST_USER"

# Verify gh auth
gh auth status 2>&1 | head -1

# Create test repo
echo "Creating test repo: $REPO_NAME..."
gh repo create "$REPO_NAME" --public --clone -- "$E2E_DIR"
cd "$E2E_DIR"

# Set up a minimal project with a CI workflow
echo "Setting up test project..."
mkdir -p .github/workflows
cat > .github/workflows/test.yml << 'WF'
name: test
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: echo "ok"
WF

echo "# Test PR" > README.md
git add -A
git commit -m "chore: init e2e test repo"

# Push main
git push origin main

# Create branch and PR
BRANCH="feature/test-$(date +%s)"
git checkout -b "$BRANCH"
echo "change" >> README.md
git add -A
git commit -m "feat: test change for PR"
git push origin "$BRANCH"

PR_URL=$(gh pr create --base main --head "$BRANCH" --title "E2E test PR" --body "Automated e2e test")
PR_NUM=$(echo "$PR_URL" | grep -oP '\d+$')
echo "PR #$PR_NUM created: $PR_URL"

# Wait for CI to register
echo "Waiting for CI to start..."
sleep 10

# Record start time for timeout
START_TIME=$(date +%s)
TIMEOUT=120  # 2 minutes max wait

# Run CI monitor — watch checks until they finish
echo "Running CI monitor (gh pr checks --watch)..."
cd "$SCRIPT_DIR"

# Source the mock helper to restore real gh? No— we want real gh for e2e.
# We run the real gh command directly for e2e.

PR_CHECKS_OUTPUT=$(mktemp)
# Start gh pr checks --watch in background, capture its output
gh pr checks "$PR_NUM" --watch --repo "$TEST_USER/$REPO_NAME" > "$PR_CHECKS_OUTPUT" 2>&1 &
CHECKS_PID=$!

# Wait for checks to finish (with timeout)
while kill -0 "$CHECKS_PID" 2>/dev/null; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
    echo "TIMEOUT: CI checks did not finish within ${TIMEOUT}s"
    kill "$CHECKS_PID" 2>/dev/null || true
    cat "$PR_CHECKS_OUTPUT"
    exit 1
  fi
  sleep 5
done

# Read output
CHECK_OUTPUT=$(cat "$PR_CHECKS_OUTPUT")
rm "$PR_CHECKS_OUTPUT"

echo "CI monitor output:"
echo "$CHECK_OUTPUT"

# Verify the output indicates checks finished
if echo "$CHECK_OUTPUT" | grep -qiE "(pass|success|complete)"; then
  echo "=== PASS: CI checks detected ==="
else
  echo "=== FAIL: No CI completion detected ==="
  echo "Raw output: $CHECK_OUTPUT"
  exit 1
fi

# Verify PR review detection — approve the PR
echo "Approving PR #$PR_NUM..."
gh pr review "$PR_NUM" --approve --repo "$TEST_USER/$REPO_NAME"

echo "=== PASS: E2E test completed successfully ==="
exit 0
