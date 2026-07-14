# PR Watch-Over

An agent skill that monitors a GitHub pull request for CI state changes and review events, optionally applying fixes and pushing commits in response.

## Language

**PR Watch-Over Session**:
A session started via `/pr-watch-over <pr-number>` that monitors a single PR until a terminal state or exhaustion.
*Avoid*: watch session, monitor task

**CI Check**:
A single GitHub Actions check run (part of a workflow). Tracked via `gh pr checks --watch`.
*Avoid*: CI pipeline, build step

**Review Event**:
A `pull_request_review` event — `approved`, `changes_requested`, `commented`, or `dismissed`. Polled via `gh pr view --json reviewDecision,reviews`.
*Avoid*: review action, feedback

**Auto-Fix**:
A code change applied by the agent in response to a CI failure or changes_requested review. Pushed as a new commit (no force push).
*Avoid*: auto-patch, bot fix

**Fix Round**:
One cycle: CI fail → diagnose → fix → push → wait for next CI run. Max 3 rounds before escalation.

**Terminal State**:
PR is `MERGED` or `CLOSED`. At this point the session exits unconditionally.

**Escalation**:
After 3 failed fix rounds, agent comments on the PR with a failure summary and exits.

## Architecture

- **CI Monitor**: `gh pr checks --watch` running as a background Monitor. Stays alive across pushes.
- **Review Poller**: Separate polling loop checking review state every 30s. Fires on `APPROVED` (exit) or `CHANGES_REQUESTED` (trigger fix cycle).
- **Fix Engine**: Agent analyzes failure/request, applies changes, commits, pushes. Runs inside the skill, not as a Monitor.
- **Exit Conditions**: (a) CI all green + PR approved, (b) PR merged/closed, (c) 3 rounds exhausted + escalation posted.
