# Contributing

Use trunk-based development with small pull requests and feature flags for incomplete work.

## Change workflow

1. Define the observable behavior and failure recovery.
2. Add or update a deterministic test/fixture.
3. Implement behind an existing port or introduce a reviewed port.
4. Run the fast quality lane.
5. Attach eval, migration or platform evidence required by the risk level.

Coverage is a supporting signal. Critical behavior, corpus success rates and invariants are blocking even when line coverage is high.
