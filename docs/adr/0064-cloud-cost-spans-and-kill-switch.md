# ADR-0064: Cloud cost spans and remote kill switch

## Status

Accepted for CLOUD-005 core on 2026-08-06.

## Context

Managed AI, extraction, cloud TTS, and podcast transcription use different
units and Providers but share the same spend and incident risks. Aggregate
invoices arrive too late to stop an abnormal route. A remote disable control
must resist forgery and rollback, selectively stop cloud capabilities, and
never become an entitlement grant or a dependency of local reading.

## Decision

1. Every paid attempt emits a `CloudOperationSpan` with a stable span ID,
   operation hash, cloud capability, server-owned route and model IDs, UTC
   start/end, stable outcome, integer micro-cost, and bounded input/output unit
   counts. Spans never contain account/article/source IDs, URLs, titles, text,
   audio, prompts, outputs, credentials, Provider errors, or raw idempotency
   keys.
2. Span writes are idempotent by span ID; different evidence under the same ID
   is an explicit conflict. Aggregation groups exact integer cost, count,
   failures, and duration by capability and model. No floating-point currency
   is introduced.
3. Each cloud capability has a rolling-window maximum and a lower or equal
   single-operation maximum. Exceeding either trips that capability locally.
   Trips remain closed until an explicit operator reset and do not spill into
   unrelated capabilities.
4. Remote policy is a versioned, signed snapshot with UTC issue/expiry times,
   a seven-day maximum lifetime, a bounded reason code, and a set of disabled
   cloud capabilities. The canonical payload sorts capabilities before
   verification. A snapshot can only disable; it cannot grant entitlement,
   choose a Provider/model, change pricing, or enable a client feature.
5. Refresh rejects invalid signatures, expired or excessively future-dated
   snapshots, version rollback, and same-version mutation. Persistence occurs
   only after verification. A failed refresh leaves the last known good value
   intact.
6. Missing or expired policy fails closed for cloud operations. A valid policy
   and the local cost guard are combined: either may deny. Every denial states
   that the local core is unaffected. Reading, subscriptions, cached full text,
   offline content, system TTS, podcast playback, annotations, and local
   knowledge do not call `CloudRuntimeGate`.
7. Production adapters must use an asymmetric signature verifier, an atomic
   durable snapshot store, authenticated distribution, server-side enforcement
   in addition to client hints, and monitoring that pages on trips. This core
   intentionally contains no signing private key or remote configuration URL.

## Verification

- Unit tests cover model/capability aggregation, exact cost, duplicate/conflict
  spans, single and rolling cost trips, window expiry, selective remote disable,
  forged snapshots, version rollback, same-version mutation, missing/expired
  policy, composed cost gating, manual reset, diagnostic privacy, and local
  fallback.
- Deterministic Harness replay fixes four release drills: rolling cost anomaly,
  selective remote disable, forged snapshot rejection, and local reading while
  cloud is fail-closed.
- Tests use injected sources, verifiers, clocks, and stores. No telemetry
  backend, remote config service, signing key, production alert, or cloud
  resource is created by this change.

## Rollback

Remove the governance observer and gate from cloud composition roots or reset a
false-positive local trip after reviewing the exact spans. Local product paths
remain outside the gate. Retain server-side emergency disable support until all
affected client and service versions have been rolled back.
