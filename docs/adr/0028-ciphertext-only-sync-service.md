# ADR-0028: Ciphertext-only sync service

Status: Accepted

## Decision

River's SYNC-007 service kernel accepts only authenticated encrypted envelopes
from active devices. It routes by bounded account, device, object and mutation
metadata and never receives a data key, recovery code, decoded payload,
article body, summary, note or provider credential. The administrator API
returns only mutation count, encoded byte count and latest sequence; it has no
clear-text or payload-decoding operation.

Push is account/device scoped and atomically enforces stored-byte and mutation
quotas. Exact mutation replay is idempotent; reuse of a mutation ID with a
different authenticated envelope is rejected. Pull is account scoped,
monotonic and bounded by the protocol page limit. Pending and revoked devices
fail before storage access. A fixed UTC request window rate-limits each
account/device independently and returns a bounded retry delay.

Audit events contain operation, outcome, account/device metadata, item count
and UTC time only. They never contain an envelope, ciphertext, clear text,
token or key. Cloud deletion removes the account's encrypted records and
returns a same-account completion receipt.

## Backup and recovery

Backups contain ordered encrypted wire envelopes and a SHA-256 checksum bound
to the account ID. Restore verifies the checksum, account scope, unique
mutation IDs and target emptiness before replacing any state. A recovery drill
restores into an isolated store and reports only record count, encoded bytes,
latest sequence and completion time, so production state is untouched.

The in-memory storage is the executable reference implementation of the
storage contract. A durable deployment adapter must preserve the same atomic
append, sequence, quota, checksum and deletion semantics.

## Verification and rollback

Tests cover active and revoked devices, tenant isolation, exact replay,
mutation collision, atomic quota rejection, per-device rate-limit recovery,
cloud deletion, backup checksum corruption, isolated recovery drills and
ciphertext-preserving sequence restoration.

Rollback can stop accepting network requests while retaining encrypted storage
and backups. It must not expose an administrator decrypt path, bypass quota or
authorization checks, or restore an unverified backup.
