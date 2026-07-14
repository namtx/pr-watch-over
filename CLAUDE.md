# pr-watch-over

Agent skill for watching over a GitHub PR — monitors CI checks and review state, responds with auto-fixes.

## Quick start

```bash
# Watch over PR #123 (in current repo)
claude "/pr-watch-over 123"
```

## Workflow

1. User invokes `/pr-watch-over <pr-number>` 
2. Run `scripts/orchestrator.sh <pr-number>` to check state
3. Interpret exit code and take action per SKILL.md
4. After fix/push, loop back with `--round N+1`

## Requirements

- `gh` authenticated
- `jq` installed
