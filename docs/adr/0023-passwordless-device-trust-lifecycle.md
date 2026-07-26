# ADR-0023: Passwordless authentication and device trust lifecycle

Status: Accepted

## Decision

River Account uses a vendor-neutral passwordless-email flow for the first
authentication implementation. The sync package owns the challenge, session,
device-join and revocation state machine; a remote identity adapter owns email
delivery, proof validation, account lookup, rate limiting and token issuance.
No password hash enters a River client.

The first device registered for an account becomes active. A later device may
complete the email proof but remains `pendingApproval` and may only refresh its
approval status. An existing active device must inspect the pending request and
upload an account data key wrapped specifically for the new device public key.
The client rejects an approval if account, sender, recipient, request status or
request expiry does not match. The server must repeat all checks and consume
each approval once.

Login completion carries a stable idempotency key. Replaying one completion
returns the same account/device registration instead of creating duplicate
devices. Challenges and sessions use explicit UTC expiry. Every sync start asks
the identity service to refresh and re-authorize the device, so an otherwise
unexpired token cannot bypass device revocation.

Access tokens, refresh tokens and passwordless proofs are opaque, redact their
string representation, and cross only the identity gateway and secure-session
vault ports. The production vault adapter must use Android Keystore-backed
storage, iOS Keychain and Windows Credential Locker/DPAPI. Tokens, proofs and
email addresses must not enter the ordinary SQLite database, analytics, crash
reports or logs.

## Offline and local-data behavior

Authentication, approval, listing, revocation and cloud sync return a stable
retryable `offline` result when no link is available. River's local reading,
search, downloads, TTS and edits remain available. Offline detection never
deletes a cached session.

An expired local access session is visible as expired and may be refreshed when
online. If the identity service reports session expiry or device revocation,
the secure session is cleared. Signing out also clears only secure session
state. None of these actions delete subscriptions, articles, knowledge items,
outbox mutations or downloaded content. Cloud-account deletion and local-data
deletion remain explicit, separate operations.

## Revocation

An active device may revoke another active or pending device. The response must
require account-data-key rotation before more future payloads are uploaded.
Revocation cannot make the removed device forget keys and plaintext it already
possessed. River therefore communicates that it protects future synchronized
versions, not historical data on a compromised endpoint.

The last active device cannot be revoked through the device-management flow;
that action belongs to the separately confirmed account-deletion/recovery
flow. Self-revocation clears the local secure session after server success.
Rejected, expired and already-consumed approvals are idempotent failures.

## Threats and follow-up

Passwordless email inherits mailbox compromise, phishing and link-forwarding
risk. The service adapter must use single-use short-lived challenges, bind proof
completion to the idempotent device registration, rate-limit by account and
network signals, and never place a long-lived token in a URL. Device approval UI
must show device name, platform and a verifiable key fingerprint before the user
confirms.

SYNC-002 defines the client contract and deterministic state machine but does
not pretend a fake local account is production authentication. SYNC-003 will
implement key generation/wrapping and secure storage; a deployable identity
adapter and recovery policy must pass integration and abuse tests before cloud
sync is enabled by default.
