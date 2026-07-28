# ADR-0038: Knowledge source identity and external mappings in schema v13

## Context

River's original `knowledge_items` table was sufficient for local full-text
search, but it did not expose a domain object or a stable source identity.
Connector code still accepted an `Article`, which meant a remote export could
become the accidental source of truth and could not safely represent a podcast,
web clip, or detached legacy item.

The same knowledge object may be exported to several connectors and several
destinations within one connector. Repeated saves must update the same local
object and remote mapping without deleting user data created by older builds.

## Decision

- `KnowledgeItem` is the connector-facing source of truth. It snapshots source
  citation, Markdown, sanitized HTML, optional summary, highlights, notes, tags,
  topics, entities, save/update times, and a content hash.
- A `KnowledgeSourceReference` has a kind, source ID, canonical public URL,
  source title, author, and publication time. `(source_kind, source_id)` is the
  local deduplication identity.
- New content hashes use SHA-256 over canonical JSON. Set-like metadata is
  sorted and deduplicated; ordered notes and excerpts retain their order.
  Existing bounded legacy hash identifiers remain readable.
- Schema v13 adds the source citation and snapshot columns to
  `knowledge_items`, plus a unique partial source index.
- Existing duplicate article knowledge rows are never deleted. The earliest row
  keeps the article source identity; additional rows receive independent
  `manual / legacy:<knowledge-id>` identities before the unique index is built.
- `knowledge_external_mappings` uses
  `(knowledge_item_id, connector_id, destination_id)` as its primary key and
  stores the remote object ID, optional public URL, and last exported content
  hash. Deleting a knowledge item cascades its mappings.
- Saving a source that already exists preserves the first River knowledge ID
  and original saved time while updating its snapshot and content hash.
- Timestamped stale retries cannot overwrite a newer local snapshot or external
  mapping; mapping updates also preserve the original mapping creation time.
- Deleting the original article only clears the optional article foreign key;
  the source citation and knowledge snapshot remain owned by the user.

## Consequences

Repeated and concurrent local saves converge on one knowledge object. A future
Notion, Markdown, Obsidian, WebDAV, or IMA adapter consumes the same
`KnowledgeItem` and can decide whether an external update is required by
comparing hashes.

The v12 fixture verifies metadata backfill, duplicate preservation, and index
creation. The interrupted v13 fixture verifies partial columns and a previously
written external mapping survive recovery.

## Rollback

Schema v13 is additive. Feature rollback keeps the new columns, source index,
and external mapping table while hiding knowledge export entry points. Older
binaries must not open a committed v13 database. Connector rollback must never
delete local knowledge items or external objects automatically.
