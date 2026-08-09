# ADR-0066: Idempotent usage grants and ledger

## Context

River Pro needs capability-level quotas without charging for failed or
cancelled work. Client retries, concurrent executors, delayed results, duplicate
callbacks, and customer-service refunds must converge on one balance. A plain
integer counter cannot reserve capacity safely or explain how a balance was
reached.

## Decision

1. A `UsageGrant` binds one stable grant ID to one paid `EntitlementKey`, a
   positive integer unit limit, and a half-open UTC validity period. Free
   capabilities cannot be metered by this ledger.
2. Every paid operation first reserves units using a stable operation ID and a
   privacy-safe 64-character request hash. The operation ID is idempotent only
   for the exact grant, capability, hash, and unit count; reuse with different
   evidence fails closed.
3. Reserved capacity participates in availability checks, so serialized
   concurrent requests cannot overdraw a grant. Only a usable result transitions
   to `committed`; failure and cancellation transition to `released` and consume
   zero units.
4. A committed entry can transition once to `refunded`. Repeated commit,
   release, or refund notifications return the existing terminal entry. A
   contradictory terminal transition is rejected rather than rewriting history.
5. The ledger derives used, reserved, remaining, and available balances from
   immutable operation entries. It never trusts a caller-provided balance.
6. Crossing the ceiling of 80% or reaching 100% creates one stable notice per
   grant and threshold. A single large settlement may emit both notices;
   retries and later refund/re-consumption cannot duplicate them.
7. IDs, hashes, capability, integer units, status, and UTC timestamps are the
   complete ledger evidence. Article/audio content, prompts, AI outputs,
   credentials, store receipts, and product identifiers are forbidden.

## Evidence

- Unit tests cover exact retry settlement, evidence conflicts, failed and
  cancelled releases, duplicate refunds, concurrent overdraw prevention,
  separate and combined 80%/100% crossings, capability mismatch, and validity
  boundaries.
- Fixed Replay covers retry, failed output, duplicate refund, concurrent
  reservation, and exact notices. It records three committed units, five
  refunded units, one rejected overdraw, and two notices.

## Consequences

The current COM-002 core serializes mutations within one ledger instance. The
authoritative multi-device service in COM-005 must persist the same entry state
machine in a transactional database with unique operation and notice keys; it
must not replace it with a mutable balance counter. COM-003 store callbacks are
inputs to grants, not direct ledger mutations.

## Rollback

Disable new paid operations while preserving ledger entries for reconciliation.
Do not reset balances, delete refund evidence, or meter any Free capability.
