# ADR 0039: Canonical knowledge Markdown v1

- Status: Accepted
- Date: 2026-07-28

## Context

River must send one knowledge object to local Markdown, Notion, IMA-assisted
sharing, and future connectors without each adapter inventing a different
document. The representation also needs to remain stable across devices and
locales so an unchanged item does not cause an external update.

User and publisher-controlled metadata can contain YAML or Markdown syntax.
Titles can also be identical or contain characters that Android, iOS, or
Windows file providers reject.

## Decision

`KnowledgeMarkdownRenderer` is the only canonical knowledge-to-Markdown
renderer. Version 1 has these rules:

1. YAML Front Matter keys and body sections have a fixed order and fixed
   English names. Connectors do not localize or reorder them.
2. All YAML strings use JSON double-quoted scalar syntax, which is valid YAML
   1.2. Tags, topics, and entities are trimmed, deduplicated, and sorted.
3. Dates are emitted in UTC ISO 8601. Line endings are LF and every document
   has exactly one final newline.
4. The body contains the title and source attribution, then optional summary,
   article Markdown, highlights with their notes, and standalone notes.
   Publisher Markdown is preserved as the article body; generated annotations
   are escaped as text.
5. Suggested filenames replace cross-platform forbidden characters, cap the
   title at 180 UTF-8 bytes without splitting a code point, and append the
   first 12 hexadecimal characters of SHA-256 over the River knowledge ID.

The knowledge content hash remains the semantic change detector. The rendered
document includes that hash but does not replace it with a hash of presentation
bytes.

## Consequences

- Local files and external connectors consume the same byte-stable document.
- A locale, tag insertion order, CRLF source, or duplicate title cannot create
  spurious updates or overwrite another item.
- Changing the structure or escaping rules requires a new
  `river_schema` version and compatibility tests.
- Actual filesystem/ZIP writing, image localization, connector retries, and
  destination-specific block mapping remain separate tasks.
