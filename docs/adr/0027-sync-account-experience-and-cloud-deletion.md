# ADR-0027: Sync account experience and cloud deletion

Status: Accepted

## Decision

River exposes account sync as an optional injected experience instead of
coupling the Flutter shell to a specific cloud implementation. The pure-Dart
controller restores the secure session, reads durable replica status, maps
incremental-sync failures into ready, retryable or blocked states, serializes
explicit retry, and provides bounded conflict history.

The Drift status repository reports device-scoped outbox depth and cursor plus
account-scoped unresolved conflicts. Conflict history is newest-first, bounded
to at most 500 rows and exposes resolution metadata without exposing clear
payloads in the UI.

Signing out clears only the secure session. It does not delete subscriptions,
articles, extracted full text, reading state, audio progress, knowledge items
or the durable local replica. Cloud deletion is a separate destructive
operation on the identity gateway. River clears the secure session only after
receiving a completed deletion receipt for the same account. Failure or a
scope mismatch leaves both session and local data unchanged.

## User experience

The cross-platform page shows device identity, pending mutations, unresolved
conflicts, server cursor, retry state and conflict history. Retryable failures
retain an explicit action. Sign-out confirmation states that local data is
preserved. Permanent cloud deletion requires the exact phrase
`删除云端数据` and states that it is irreversible while local articles remain.

The app dependency graph accepts the experience as an optional port. A cloud
adapter can enable the navigation entry without changing the page or domain
state machine; local-only builds remain unaffected.

## Verification and rollback

Tests cover status scoping, ordered conflict history, offline retry and
recovery, safe sign-out, scoped cloud deletion, status/history rendering and
the destructive confirmation gate. Rollback may hide the injected navigation
entry, but must not merge sign-out and cloud deletion or add local deletion to
either operation.
