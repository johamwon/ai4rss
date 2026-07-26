# ADR-0024: Client cryptography and secure vault

Status: Accepted

## Decision

River uses the pinned `cryptography` 2.9.0 package instead of implementing
cryptographic primitives. Sync payloads use AES-256-GCM with a fresh 96-bit
nonce and the canonical protocol associated data from ADR-0022. Device key
agreement uses X25519. Account data keys are wrapped with an ephemeral X25519
key, a 256-bit random HKDF-SHA-256 salt, domain-separated HKDF info and
AES-256-GCM. Key and nonce randomness enters through an injected source; the
production composition must construct it with `Random.secure()`, while tests
use deterministic sequences.

The crypto API owns redacting, destructible device-private-key, account-data-key
and recovery-secret material. Explicit export returns a copy only for the secure
vault adapter. Destroy overwrites owned buffers on a best-effort basis.
Managed-language copies, operating-system crypto implementations and garbage
collection mean River does not claim perfect memory erasure.

Every decrypt operation validates account, data-key ID, algorithm and
recipient scope before authentication. A wrong key, modified ciphertext or
modified routing metadata fails closed with a stable authentication failure.
Tests include a cross-runtime fixed AES-256-GCM vector, ciphertext/plaintext
separation, AAD modification, wrong and destroyed keys, X25519 recipient
isolation, rotation and recovery.

## Recovery

Recovery uses a random 256-bit secret shown as canonical base64url and never
stored by River's cloud service or secure vault. HKDF-SHA-256 derives a recovery
wrapping key from that secret and a random 256-bit salt; AES-256-GCM wraps the
account data key in a server-storable recovery bundle. A wrong recovery code
returns only authentication failure.

The client displays the code in a selectable, read-only warning dialog. The
continue action remains disabled until the user confirms an offline save. The
dialog states that the service cannot recover the code and deliberately offers
no default clipboard/cloud-copy action. Account onboarding will integrate this
component when the deployable identity adapter is available.

## Secure storage

River pins `flutter_secure_storage` 10.3.1:

- Android uses API 23+ Keystore-backed RSA-OAEP and AES-GCM defaults. App backup
  is disabled so encrypted blobs are not restored without their device key.
  `resetOnError` is disabled to prevent silent key deletion.
- iOS uses non-synchronizable Keychain items with
  `first_unlock_this_device`, allowing background work after the first unlock
  without migrating secrets through iCloud.
- Windows uses the resolved 4.1.0 backend and DPAPI. All operations are
  serialized in one process-level vault to avoid concurrent file locking. The
  4.2 line currently conflicts with the pinned `share_plus` Win32 dependency;
  they must be upgraded together.

Session, device-key and data-key records use a versioned JSON schema inside
secure storage. Key identifiers are base64url-encoded before becoming storage
keys. Corrupt or future-schema values fail without automatic deletion. Signing
out deletes only the session record; key deletion and local content deletion
remain explicit operations.

## Verification and rollback

Pure-Dart tests use deterministic randomness and never call a real network.
Platform contract tests use an in-memory secure store and verify serialization,
corruption behavior and single-operation concurrency. A Windows integration
test writes, reads and deletes a session, X25519 private key and account data
key through the real DPAPI backend. Windows Debug build and this integration
test are blocking Merge/Nightly evidence.

Rollback disables cloud sync and leaves local RSS data untouched. Existing
secure records are not downgraded, copied to SQLite or silently removed.
