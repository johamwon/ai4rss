# ADR 0071: Portable Obsidian and WebDAV knowledge connectors

- Status: Accepted
- Date: 2026-08-06

## Context

River needs portable knowledge export beyond the existing Notion flow. The
connector boundary must work on Android, iOS, and Windows without making the
internal knowledge object depend on a remote service. It also needs explicit
conflict, retry, and privacy behavior for directories and WebDAV servers.

The existing Notion export coordinator already uses a canonical content hash
and persisted external mapping to skip unchanged content and update changed
pages. INTEL-004 therefore reuses that incremental contract rather than adding
a second Notion synchronization mechanism.

## Decision

Introduce a provider-neutral `KnowledgeDocumentStore` port and two adapters:

- `ObsidianKnowledgeConnector` writes canonical River Markdown beneath one
  configured directory. Creates are idempotent, writes are atomic through the
  store port, updates use an expected revision, and the original stable file
  path survives title changes.
- `WebDavKnowledgeConnector` stores the same canonical Markdown as one safe URI
  segment below a configured HTTPS base URI. Creates use `If-None-Match: *`;
  updates and deletes first read the current ETag and then use `If-Match`.

Both adapters return stable connector failures. Conflicts, rate limits,
timeouts, and offline failures are retryable where appropriate. Authentication,
payload-size, storage-capacity, and unsafe-path failures are explicit. Remote
response bodies, document content, credentials, and full target URIs never
enter diagnostics.

Obsidian paths reject absolute paths and traversal. WebDAV rejects credentials,
queries, fragments, unsafe object IDs, and insecure HTTP by default. Retry-After
integer seconds are bounded to one hour; scheduling remains the caller's job.

## Consequences

- Connector behavior is deterministic and testable without filesystem or
  network access.
- External conflicts cannot silently overwrite user edits.
- Internal knowledge objects remain available when either destination is
  offline.
- A platform layer must implement atomic directory replacement and an HTTP
  transport that does not weaken TLS or redirect policy.
- Native vendor-specific APIs can be added behind the same boundary, but cannot
  weaken the portable contract.

## Verification

Fast Lane covers idempotent Obsidian creation, stable paths, revision conflicts,
path containment, WebDAV create/update ETags, duplicate creates, rate limiting,
offline retry mapping, and diagnostic privacy. A fixed five-case connector
replay is part of the aggregate Harness.
