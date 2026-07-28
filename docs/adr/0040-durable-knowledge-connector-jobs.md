# ADR 0040: Durable knowledge connector jobs

- Status: Accepted
- Date: 2026-07-28

## Context

Saving to an external knowledge system can fail after the remote object was
created but before River persisted its external ID. Mobile processes can also
be suspended during a request, and a user can edit the knowledge item while an
older snapshot is being exported. A direct connector call from UI or a service
would therefore risk duplicate pages, lost edits, and failures that disappear
after restart.

Connectors must expose useful recovery state without leaking provider response
bodies, credentials, workspace names, or raw exceptions into durable storage.

## Decision

Every connector implements a provider-independent protocol:

- `testConnection`
- `create`
- `update`
- `delete`
- `status`

Create, update, delete, and status requests carry explicit destination and
external object identities. Connector failures expose only a stable code, a
retryable flag, and an optional retry delay. Public external URLs are validated
at the domain boundary.

`DurableKnowledgeExportManager` is the only application-facing export path. It
uses the existing `PersistentJobQueue` with separate upsert and delete job
types. A payload contains only the River knowledge item ID, connector ID, and
destination ID; content and credentials are loaded at execution time.

An upsert chooses create or update from the durable external mapping:

- Create uses one target-stable idempotency key, including across process
  restarts and retries.
- Update uses the same target identity plus the knowledge content hash.
- An already exported hash completes without a provider call.
- After completion, the manager reloads the knowledge item. A changed hash
  requeues the same job so an edit made during the provider call is not lost.

Calls time out after 45 seconds. Retryable failures use bounded exponential
backoff or a provider Retry-After capped at 30 minutes. Five exhausted attempts
enter the existing failed/dead-letter state; only explicit retry resets that
budget. Non-retryable failures stop immediately. Delete treats provider
`notFound` as idempotent success.

On process start, all knowledge-export leases are reclaimed, including
unexpired leases owned by the terminated process. The stable external
idempotency key makes replay safe.

## Consequences

- External connector downtime never removes the local knowledge object.
- A crash between remote success and local mapping persistence retries safely.
- UI and future automatic exports observe the same queued/running/succeeded/
  failed model and can offer an explicit retry action.
- Connectors remain responsible for translating their provider response into
  the bounded protocol. OAuth and provider-specific object mapping are separate
  tasks.
