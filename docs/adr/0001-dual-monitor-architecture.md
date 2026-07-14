# ADR-0001: Dual-monitor architecture for PR watch-over

The skill needs to react to two fundamentally different event types — CI state changes and review events — with different delivery characteristics. CI checks emit a stream of structured state transitions (pending → running → success/failure); review events are discrete state-snapshots with no streaming protocol. Rather than building a single combined watcher that handles both (complex, coupled), the skill runs two independent monitors: `gh pr checks --watch` for CI (blocking, real-time, zero token cost while waiting) and a polling loop over `gh pr view --json reviewDecision,reviews` for reviews (30s interval, lightweight). This separation keeps each watcher simple, testable, and independently replaceable if GitHub's API surface changes. A single orchestrator script coordinates the two monitors and routes events to the fix engine.

**Considered Options:**
- `gh-watch` CLI extension (`justincampbell/gh-watch`): single binary, rich event types, but adds an external dependency with its own install/update lifecycle. Dependency risk outweighed by simplicity for v1.
- Single polling loop: simpler code but burns tokens on every poll cycle and misses the real-time semantics of `gh pr checks --watch`. Rejected because CI monitoring is the latency-sensitive path.
- Webhook listener (local server): delivers true push events, no polling overhead, but requires a publicly-addressable endpoint or tunnel (ngrok), adds a persistent process, and doesn't integrate cleanly with Claude Code's Monitor tool.

**Consequences:**
+ Each monitor can be started, stopped, and tested independently
+ CI monitor uses OS-level blocking — zero token cost while waiting
+ Review poller can be removed or swapped for webhooks later without touching the CI path
- Two monitors means two process slots in the session
- Review poller introduces 30s latency on review detection
- Orchestrator must deduplicate and sequence events from two sources
