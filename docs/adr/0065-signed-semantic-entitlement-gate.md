# ADR-0065: Signed semantic entitlement gate

## Context

River Free must remain a useful local-first RSS reader while River Pro funds
managed AI, cloud processing, sync, and advanced connectors. Android, iOS, and
Windows stores use unrelated product identifiers, and those identifiers can
change by region or commercial experiment. UI code must therefore ask for a
semantic capability rather than infer access from a SKU or receipt.

Paid access also needs to survive a bounded offline period without trusting a
mutable local boolean. A cached grant must be bound to one River Account,
signed by the entitlement service, resistant to rollback, and unable to remove
the permanent Free product.

## Decision

1. `EntitlementKey` is the only feature-facing contract. A fixed matrix marks
   subscriptions, local/full-text/offline reading, system TTS, podcast
   playback, local knowledge, portable export, and BYOK as Free. Managed AI,
   encrypted sync, cloud extraction/TTS, podcast transcription, semantic
   knowledge, and automatic connectors require a verified grant.
2. Free decisions return before account, network, cache, or signature access.
   Missing login, trial expiry, downgrade, corrupt cache, and service outage
   therefore cannot disable the local product.
3. A paid snapshot binds a SHA-256 account subject, semantic plan, exact grant
   set, monotonically increasing revision, UTC issue/refresh/expiry times, and
   signature into canonical `river.entitlements.v1` JSON. Lifetime is at most
   seven days; a Free snapshot cannot encode a paid grant.
4. Refresh verifies account binding, bounded future skew, expiry, Ed25519
   signature, revision monotonicity, and same-revision immutability before an
   atomic cache write. Invalid candidates leave the last trusted snapshot
   untouched. Cached snapshots are reverified on every paid decision.
5. A fresh snapshot works online or offline. After `refreshAfter`, paid work is
   allowed only while explicitly offline and before hard expiry; an online
   caller must refresh. This bounds revoked access without making ordinary
   offline reading dependent on River servers.
6. The three clients persist the signed snapshot through the existing secure
   key/value boundary: Android Keystore, device-only iOS Keychain, and Windows
   platform-protected storage. Schema corruption or a future schema fails
   visibly and is not silently deleted.
7. App code and pages consume only the semantic gate. Store product IDs,
   receipts, price configuration, and transaction truth remain future adapter
   concerns and must never become feature flags.

## Evidence

- `river_commerce` covers the full Free matrix, guest access, selective Pro
  grants, canonical ordering, redaction, account binding, forged signatures,
  rollback/same-revision mutation, future/expired snapshots, bounded offline
  access, refresh-required behavior, trial downgrade, corrupt cache, and Free
  snapshot privilege escalation.
- `river_platform` round-trips and clears the secure snapshot, preserves
  corrupt/future values for diagnosis, serializes plugin operations after a
  failure, and verifies a real Ed25519 signature plus payload mutation.
- The deterministic commerce replay covers guest Free, verified Pro, offline
  cache, expired trial, forged refresh, and a source scan proving application
  UI has zero store-product-identifier references.

## Consequences

The entitlement service must publish signed snapshots and protect the signing
private key; only the public key ships in clients. COM-003 and COM-005 may map
store transactions to semantic grants, but cannot bypass this gate. A seven-day
hard expiry intentionally trades a bounded offline Pro window for prompt
revocation. Free local capabilities remain available regardless.

## Rollback

Stop refreshing paid snapshots and remove paid composition-root integrations.
All Free matrix decisions continue locally. Do not remove or narrow the Free
matrix as part of a payment rollback, and do not delete user content.
