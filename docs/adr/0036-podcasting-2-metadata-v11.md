# ADR-0036: Podcasting 2.0 metadata and schema v11

## Context

River can subscribe, download and play standard Podcast RSS, but episodes lose
official Podcasting 2.0 chapter and transcript links during refresh. Chapters
must remain editable outside the media file, and multiple transcript formats or
languages may be advertised for one episode.

The locked Podcast Namespace defines one `podcast:chapters` element with an
external `application/json+chapters` document and multiple
`podcast:transcript` elements. The prefix is not semantically significant; the
namespace URI is.

## Decision

- Match the exact Podcast Namespace URI while accepting any XML prefix.
- Accept only HTTPS chapter and transcript resources without credentials.
- Persist one chapter source and at most eight deduplicated transcript
  references per episode.
- Store the chapter URL/type in explicit columns and transcript reference
  metadata as bounded JSON. Transcript bodies are not stored or logged.
- Schema v11 adds `chapters_url`, `chapters_mime_type` and
  `transcripts_json` to `podcast_episodes`.
- Parse the official JSON Chapters shape locally with ordered, finite
  timestamps, a 500-chapter limit and safe optional HTTPS image/link URLs.
- Expose official transcripts through the platform's safe external-URI
  gateway. HTML or JSON transcript bodies are not rendered inside River until
  a dedicated sanitizer and format contract exists.
- Selecting a chapter loads the episode when necessary and seeks through the
  existing audio controller, preserving active playback and its durable
  progress.

## Consequences

Feed refreshes now detect metadata-only episode changes and persist them.
Malformed or unsupported optional metadata never discards an otherwise playable
episode. A chapter document failure is isolated to the metadata sheet and can be
retried by reopening it.

The v10 fixture verifies an old episode and queue survive migration. An
interrupted v11 fixture verifies already-added metadata columns retain values
while missing columns are added idempotently.

The implementation follows:

- <https://podcasting2.org/docs/podcast-namespace/tags/chapters>
- <https://podcasting2.org/docs/podcast-namespace/tags/transcript>

## Rollback

Older binaries must not open a database after schema v11 has been committed.
Feature rollback keeps the additive columns and stops presenting their UI; feed,
download, queue and playback rows remain compatible at the data level.
