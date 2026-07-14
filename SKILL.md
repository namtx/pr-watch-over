---
name: pr-watch-over
description: >
  Monitor a GitHub pull request for CI state changes and review events.
  Respond to CI failures with auto-fixes. Respond to changes_requested
  reviews by applying suggested changes. Push new commits (no force push).
  Max 3 fix rounds before escalation.
  Trigger: "/pr-watch-over <pr-number>", "watch PR #123", "watch over PR #456".
---

## Usage

```
/pr-watch-over <pr-number> [--repo owner/repo] [--round N]
```

Agent invokes `scripts/orchestrator.sh` to check current state, then:
- If CI fails → diagnose → fix → commit → push → loop (round+1)
- If changes requested → read review → apply → commit → push → loop (round+1)
- If CI pending or review pending → wait, retry later
- If all green + approved → done, exit 0
- If PR merged/closed → done, exit 0
- If max rounds (3) exhausted → comment failure summary on PR → exit

## Exit codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | All checks pass + approved, or PR merged/closed | Done |
| 1 | CI failed | Diagnose failure, fix, push, loop |
| 2 | Changes requested | Read review body, apply, push, loop |
| 3 | Still waiting (CI or review pending) | Retry later |
| 4 | Max rounds exhausted | Comment summary on PR, stop |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/orchestrator.sh` | Entry point. Runs CI check + review poll, emits events |
| `scripts/ci-monitor.sh` | Single-shot `gh pr checks --json` wrapper |
| `scripts/review-poller.sh` | Single-shot `gh pr view --json reviewDecision,latestReviews` wrapper |

## Events emitted

```
[ci:pass] all checks passed for PR #42
[ci:fail] checks failed for PR #42: test
[ci:pending] checks still running for PR #42
[ci:check] name=lint state=pass link=https://...
[review:approved] PR #42 approved
[review:changes_requested] PR #42 author=reviewer1 body=Please rename the variable
[review:pending] PR #42 awaiting review
[review:commented] PR #42 has 2 comment(s)
[terminal] PR #42 state=MERGED
[escalate] max rounds (3) exhausted
[waiting] PR #42 not yet ready
```

## Requirements

- `gh` CLI authenticated with `repo` scope
- `jq` installed
- Bash 3.2+ (macOS) or Bash 4+ (Linux)
