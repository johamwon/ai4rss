# ADR-0037: Article annotation anchors and schema v12

## Context

River's reader can progressively replace Feed text with cached or newly
extracted full text. A highlight stored only as character offsets can silently
move to unrelated text after that replacement, while a quote stored without
position or context cannot safely distinguish repeated sentences.

The current reader renders a plain-text document, but future renderers may
preserve multiple DOM text nodes. The annotation contract therefore needs to
work for both representations without coupling the domain layer to Flutter or
an HTML parser.

## Decision

- Represent a document as ordered text nodes with stable DOM-style paths.
- Capture both DOM start/end points and a text-quote anchor containing the exact
  selection, up to 64 characters of prefix/suffix context, original offsets,
  and content revision.
- Resolve in this order: unchanged revision and offsets, DOM points whose text
  still matches, then exact quote plus surrounding-context scoring.
- When repeated candidates have the same best context score, mark the
  annotation orphaned instead of choosing by proximity alone.
- Bound one selection to 16,384 characters, a note to 20,000 characters, and
  persisted identifiers, revisions, paths, and contexts.
- Schema v12 adds the `article_annotations` table with an article foreign key
  and cascading deletion. An upsert by annotation ID makes note/color edits
  idempotent.
- The current plain-text reader supplies one `/article/text()[1]` node. A rich
  document renderer can later supply multiple real text-node paths without
  changing the anchor or repository contract.
- Attached annotations render alongside, rather than replacing, the active TTS
  sentence highlight. Orphaned annotations remain visible in the management
  sheet with an explicit lost-anchor state.

## Consequences

Highlights and notes survive deterministic full-text reparsing when their quote
can be uniquely recovered. The system deliberately prefers a visible orphan
over silently attaching a note to the wrong repeated phrase.

The v11 fixture verifies article state survives migration. An interrupted v12
fixture verifies a previously created annotation table and row are retained.

## Rollback

Older binaries must not open a database after schema v12 has been committed.
Feature rollback keeps the additive annotation table and hides annotation UI;
feeds, articles, knowledge items, audio, podcasts, and sync rows remain
unchanged. Deleting the table is not part of application rollback.
