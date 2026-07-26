# ADR-0026: Deterministic sync conflict resolution

Status: Accepted

## Decision

River resolves SYNC-005 conflicts on clients without exposing clear text to the
server. Every changed upsert field carries a UTC timestamp, author device ID
and mutation ID. Unchanged fields retain their previous metadata. Legacy v1
payloads without field metadata remain readable and use their authenticated
envelope metadata as a deterministic fallback.

Concurrent subscription, folder and knowledge-metadata edits use field-level
last-write-wins. Ties are ordered by timestamp, device ID, mutation ID and
finally the canonical field value. Article state merges monotonically useful
reading facts: read is an OR, active time and scroll depth take their maximum,
and completion takes the latest completion time; reversible star and
read-later flags remain field LWW. Reader settings use deterministic
record-level LWW. Audio progress uses the furthest segment, character and
position for the same content revision, but a revision change uses record LWW.

Subscription, folder and knowledge tombstones win concurrent updates. Article
state, reader settings and audio updates win concurrent tombstones. A merge
that is not already identical to either input creates a new encrypted mutation
whose vector merges both inputs and increments the resolving device. The
resolved replica, conflict audit, seen-mutation record and optional outbox row
are committed in one Drift transaction.

## Replay and retention

Drift schema v7 persists every seen mutation ID with its exact encrypted
envelope. An exact replay is idempotent and may advance the delivery cursor.
The same mutation ID paired with any different authenticated envelope is a
protocol violation and the page cursor does not advance. Conflict audit rows
record unresolved, local, remote or merged outcomes and link to the resolution
mutation when one exists.

Tombstones have a minimum 30-day retention. Compaction is permitted only after
that time and only when every active device cursor has reached the tombstone's
server sequence. Revoked devices do not block compaction; pending devices do
not provide proof of delivery; having no active device is insufficient
evidence to delete a tombstone.

## Verification and rollback

Tests cover independent concurrent field edits, tied clocks, semantic article
state, same/different audio revisions, tombstone priorities, legacy payloads,
duplicate and colliding mutation IDs, atomic resolved mutation persistence,
v6-to-v7 interrupted migration, an offline week and lagging/revoked device
retention. A two-device incremental test proves merged mutations converge
through the encrypted transport.

Rollback may stop creating resolution mutations, but must preserve schema v7
tables and field metadata. It must never downgrade the database or discard
seen-mutation and tombstone evidence.
