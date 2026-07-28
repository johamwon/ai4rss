# ADR 0041: Portable Markdown export bundles

- Status: Accepted
- Date: 2026-07-28

## Context

Single Markdown export, batch export, downloaded images, Notion preparation,
and IMA-assisted sharing need identical bytes and filenames. Direct filesystem
access in the knowledge package would couple this logic to one platform and
make collision, resource, and archive behavior difficult to test.

Publisher-controlled image links can return executable or oversized content,
redirect to a less secure URL, or repeat the same bytes under many URLs.

## Decision

`KnowledgeMarkdownExportBuilder` creates an in-memory, platform-independent
bundle of relative paths, media types, and bytes:

- Items are sorted by River ID and rendered with canonical Markdown v1.
- Existing title-plus-ID-hash filenames prevent ordinary title collisions.
- A bundle is limited to 5,000 knowledge items, 5,000 unique image sources,
  10 MiB per image, and 200 MiB of file payload.
- `keepRemote` preserves image links and a one-document bundle can be saved
  directly as UTF-8 `.md`.
- `download` recognizes Markdown images and HTML `img src`, fetches each source
  once, verifies PNG/JPEG/GIF/WebP signatures, addresses assets by SHA-256 of
  their bytes, and rewrites links to `assets/<hash>.<extension>`.
- Credentialed URLs, local literal addresses, HTTPS downgrade redirects,
  unsupported formats (including SVG), timeouts, and size violations fail the
  local-image export with a stable code instead of silently producing a
  partially portable archive.

Multi-file bundles use River's deterministic store-only ZIP encoder. Entries
are UTF-8, sorted, include standard CRC-32, and use a fixed DOS timestamp, so
the same bundle produces identical archive bytes.

`PlatformKnowledgeMarkdownFileGateway` is the only filesystem boundary. It
uses the system save picker for either the single Markdown bytes or the ZIP
bytes. The gateway and image fetcher are injected into the application
composition root.

## Consequences

- Android, iOS, and Windows export the same document and archive structure.
- Tests can round-trip every entry without opening a native picker.
- Store-only ZIP favors determinism and compatibility over compression. Large
  export limits bound memory because the complete bundle is prepared before
  the user selects a destination.
- Full DNS pinning remains part of the shared HTTP boundary hardening work;
  this adapter still rejects localhost and private literal addresses before
  opening a connection.
