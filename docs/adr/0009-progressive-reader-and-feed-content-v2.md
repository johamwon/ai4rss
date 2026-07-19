# ADR-0009: Progressive reader and persisted feed content

Status: Accepted

River persists the raw `content_html` supplied by a feed in the nullable
`articles.feed_content_html` column introduced by schema v2. The reader never
renders this raw value directly. It first derives a sanitized local preview,
then observes the sanitized extraction cache and replaces the preview in the
same document widget when a more complete result arrives.

The extraction adapter skips page HTTP when the feed body is already complete.
For summaries or truncated bodies it performs a bounded static-page request
before the existing Readability and platform WebView fallback stages. Cached
content remains the first choice and network or extraction failure cannot make
it unreadable.

Progressive replacement maps the viewport's text anchor and active selection
into the new document. If a non-collapsed selection cannot be mapped, the new
body is held until the selection collapses instead of discarding user state.
No article text or selection is logged.

Schema v2 is an additive, nullable migration. Versioned SQL fixtures cover a
populated v1 upgrade, an interrupted state where the column exists but the
schema version was not advanced, and a current v2 open. A code rollback must
retain schema version 2 and ignore the new column; it must not ship a binary
that attempts to downgrade an existing database. The feature can be disabled
at the composition root by restoring the previous article route while keeping
the column intact.
