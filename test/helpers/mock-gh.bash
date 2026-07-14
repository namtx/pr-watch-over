# Mock `gh` CLI for testing
# Overrides PATH so `gh` returns fixture data instead of hitting GitHub API

# Usage:
#   source test/helpers/mock-gh.bash
#   mock_gh set <command-pattern> <exit-code> <stdout-file> [stderr-file]
#   mock_gh set "pr checks 42 --watch" 0 "test/fixtures/checks-pass.txt"
#   mock_gh set "pr view 42 --json reviewDecision" 0 "test/fixtures/review-approved.json"

MOCK_GH_DIR=""
MOCK_GH_RESPONSES=""

mock_gh_setup() {
  MOCK_GH_DIR=$(mktemp -d)
  MOCK_GH_RESPONSES="$MOCK_GH_DIR/responses"

  cat > "$MOCK_GH_DIR/gh" << 'SCRIPT'
#!/usr/bin/env bash
# Mock dispatcher
RESPONSES_FILE="$GH_MOCK_RESPONSES"
if [[ ! -f "$RESPONSES_FILE" ]]; then
  echo "MOCK_ERROR: no responses file" >&2
  exit 1
fi

ARGS="$*"

while IFS='|' read -r pattern exit_code stdout_file stderr_file; do
  # Skip comments and empty lines
  [[ "$pattern" =~ ^#.*$ ]] && continue
  [[ -z "$pattern" ]] && continue

  if [[ "$ARGS" == "$pattern" ]]; then
    if [[ -n "$stdout_file" && -f "$stdout_file" ]]; then
      cat "$stdout_file"
    fi
    if [[ -n "$stderr_file" && -f "$stderr_file" ]]; then
      cat "$stderr_file" >&2
    fi
    exit "$exit_code"
  fi
done < "$RESPONSES_FILE"

echo "MOCK_ERROR: no matching pattern for: gh $ARGS" >&2
exit 1
SCRIPT
  chmod +x "$MOCK_GH_DIR/gh"
  export PATH="$MOCK_GH_DIR:$PATH"
  export GH_MOCK_RESPONSES="$MOCK_GH_RESPONSES"
}

mock_gh_set() {
  local pattern="$1"
  local exit_code="$2"
  local stdout_file="${3:-}"
  local stderr_file="${4:-}"
  echo "$pattern|$exit_code|$stdout_file|$stderr_file" >> "$GH_MOCK_RESPONSES"
}

mock_gh_teardown() {
  if [[ -n "$MOCK_GH_DIR" && -d "$MOCK_GH_DIR" ]]; then
    rm -rf "$MOCK_GH_DIR"
  fi
  # Restore PATH — remove mock dir
  export PATH="${PATH/$MOCK_GH_DIR:/}"
}

mock_gh_reset() {
  : > "$GH_MOCK_RESPONSES"
}
