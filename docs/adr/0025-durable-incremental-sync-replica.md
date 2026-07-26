# ADR-0025: Durable incremental sync replica

Status: Accepted

## Decision

River implements SYNC-004 as a bounded local-first state machine around three
ports: an encrypted transport, a durable replica store and the SYNC-003 crypto
engine. A local edit first creates a version vector, encrypts one validated
payload and atomically writes both the current replica record and outbox row.
Network availability is not required for this operation.

A sync cycle first uses the SYNC-002 authorizer to refresh the session and
device status. A pending, expired or revoked device cannot reach transport.
The cycle then uploads no more than 200 mutations per page and requires an
exact acknowledgement set before deleting any outbox row. It pulls
monotonically advancing pages from the last durable opaque cursor. Each page is
decrypted and validated completely before the store atomically applies
accepted records, stages conflicts and advances the cursor. A malformed
payload, wrong key, partial acknowledgement, non-advancing page or failed
database transaction therefore leaves retryable durable state intact.

The six v1 payload shapes are explicit and bounded:

- subscription URL, title, folder placement and enabled state;
- folder name, order and optional parent;
- per-article read, star, read-later and progress state;
- reader typography and theme settings;
- article-TTS or podcast progress and content revision;
- knowledge title, source, hash, tags and external-provider mappings.

Article bodies, knowledge markdown, generated summaries, downloaded media,
generated audio and provider credentials are not accepted by this codec.
Payload JSON uses an explicit schema and exact fields. Encrypted envelope wire
JSON also uses an explicit schema and reconstructs the protocol types so their
existing limits and associated-data invariants are revalidated.

## Durability

Drift schema v6 adds four account-scoped tables:

- the latest encrypted envelope plus decoded bounded payload per object;
- durable local outbox rows;
- one opaque pull cursor per account and device;
- pulled concurrent/equal-vector records awaiting conflict resolution.

The store uses a cursor compare-and-swap inside the same SQLite transaction as
remote record and conflict writes. Outbox acknowledgement is account/device
scoped. Record, outbox and cursor state survive process restart. Migration from
v1 through v5 is idempotent, including recovery when only part of the v6 table
set already exists.

The decoded local replica is not a second cloud trust boundary: River already
stores subscriptions, reading state, settings and knowledge metadata in its
local application database. Only ciphertext leaves the client. Secret keys,
session tokens, recovery secrets, article bodies and external-provider
credentials never enter these sync tables.

## Conflict boundary

SYNC-004 accepts causally newer records, ignores causally older or identical
records and stages concurrent or equal-vector/different-mutation records.
It deliberately does not perform field-wise or semantic payload merging.
SYNC-005 owns those deterministic conflict rules, tombstone compaction,
duplicate replay audit and resolved-mutation generation. This separation keeps
transport/cursor correctness independently testable.

## Verification and rollback

Tests run two independent devices through all six payload kinds, small-page
pagination, causal updates, tombstones, offline outbox recovery, authenticated
invalid payloads, partial acknowledgements, non-advancing cursors, transaction
failure, revoked-device preflight and concurrent conflict staging. A
deterministic randomized scenario
creates 72 disjoint offline edits across both devices and verifies convergence
after bounded incremental cycles.

Drift tests reopen a file-backed database, verify account/device-scoped
acknowledgement and prove cursor compare-and-swap rollback. Migration tests
cover v1 through v6 and an interrupted v6 table creation.

Rollback disables transport execution but preserves local content, outbox,
replica, conflicts and cursor. No rollback path deletes or downgrades these
tables.
