# ADR-0022: E2EE sync protocol and threat model

Status: Accepted

## Decision

River sync protocol v1 is local-first, client-encrypted, cursor-based and
idempotent. An account owns one current 256-bit data-key descriptor; secret key
bytes are never represented by protocol metadata or stored in the ordinary
application database. Each device has an X25519 public key and receives an
individually wrapped account data key. SYNC-003 will implement
X25519/HKDF-SHA-256 key derivation and AES-256-GCM encryption behind these
types, using operating-system secure storage for private and recovered keys.

Every uploaded mutation is an `EncryptedSyncEnvelope`. Its AEAD associated data
binds protocol version, account, object kind and ID, upsert/tombstone kind, data
key, author device, version vector, UTC client timestamp and mutation ID. The
nonce is 96 bits and the authentication tag is 128 bits. Routing metadata is
visible to the service; the object payload and tombstone body remain encrypted.
Base64 fields must be canonical, and an envelope is limited to 1 MiB.

The synchronized object set is deliberately bounded:

- subscriptions and folders;
- per-article read, star and preference state;
- reader settings;
- article-TTS and podcast progress;
- knowledge-object metadata and external mappings.

Article bodies, downloaded media, generated audio and provider credentials are
not v1 sync objects. They may be re-fetched or regenerated and must not inflate
the encrypted state channel.

Clients upload at most 200 mutations relative to an opaque server cursor and
pull monotonically advancing pages. Mutation IDs provide idempotency; server
sequence numbers order storage delivery but do not establish object causality.
Per-device version vectors establish causality. The service must never use
client wall clocks to discard an envelope.

## Conflict contract

A dominating vector replaces a dominated vector. Concurrent vectors are
resolved after decryption on a client:

- subscription and folder fields merge by deterministic per-field LWW; a
  concurrent tombstone wins;
- article state merges semantically: read/completed progress is monotonic,
  while reversible flags use per-field LWW; an active update wins a cleanup
  tombstone;
- reader settings use record-level LWW;
- playback progress keeps the furthest valid point within the same content
  revision and uses LWW across revisions;
- knowledge metadata merges fields by LWW, while explicit deletion wins.

LWW first compares UTC timestamp, then device ID, then mutation ID. It is only a
deterministic tie-break after vector comparison, never a causality signal.
Equal vectors with different mutation IDs are retained in conflict audit
history even when the deterministic winner can be selected.

## Threat model

Protected against:

- a compromised database, backup or honest-but-curious administrator reading
  synchronized payloads;
- network modification, metadata substitution and ciphertext tampering through
  TLS plus AEAD-associated-data authentication;
- duplicate, delayed and out-of-order delivery through mutation IDs, cursors,
  version vectors and tombstones;
- a revoked device receiving future data after revocation and data-key
  rotation.

Accepted residual risks:

- the service observes account/device identifiers, object kinds, object IDs,
  mutation sizes, timing and access patterns;
- an unlocked or malware-compromised client can read data available to that
  client;
- a device that already received an old data key cannot be made to forget old
  ciphertext; revocation requires rotation and only protects future versions;
- traffic analysis, screenshots, exported files and external knowledge
  providers are outside this encryption boundary;
- loss of every authorized device and the recovery secret makes server-side
  recovery impossible.

The server may authenticate accounts, authorize active devices, rate-limit,
store opaque envelopes, assign sequences and retain backups. It may not receive
private device keys, account data keys, recovery secrets or decrypted payloads.
Logs must omit ciphertext, wrapped keys, tokens and user content.

## Lifecycle and rollback

Device join requires approval from an authenticated existing device or a
recovery flow. Revocation blocks new requests immediately and queues data-key
rotation. Tombstones remain until all active-device cursors and the configured
retention window permit compaction. Account cloud deletion is separate from
local-data deletion.

Protocol versions are explicit on cursors and envelopes. Unsupported versions
fail closed without deleting local state. If cloud sync is unavailable or
rolled back, River continues reading and writing locally and preserves an
outbox for a later compatible client.
