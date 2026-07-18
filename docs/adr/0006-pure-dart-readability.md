# ADR-0006: Pure Dart Readability stage

Status: Accepted

River performs generic article selection inside `river_extract` with a
deterministic, DOM-only Readability stage. The stage receives HTML already
downloaded through the bounded HTTP port and never fetches a URL, executes a
script, reads a global clock, or calls a platform API.

Candidate blocks are ranked using paragraph length, Chinese and Latin
punctuation, semantic class/id hints, ancestor structure, and link density.
High-scoring siblings are merged so multi-section articles remain intact.
Navigation, advertising, recommendation, comment, sharing, and subscription
chrome is removed before selection. The selected fragment still crosses the
shared HTML sanitizer before it becomes an `ExtractedArticle`.

The available Flutter `readability` plugin was not selected because its native
wrapper does not cover Windows and owns URL fetching. `html_main_element` was
not selected because version 2.1.0 constrains the Dart SDK to `<3.0.0`.
`trafilatura` was not selected for this stage because its crawler, downloader,
feed, encoding, and output dependencies are broader than River's DOM-only
adapter boundary.

Inputs are capped at 5 MiB and 20,000 DOM elements. The stage is versioned and
covered by synthetic English multi-column, Chinese long-form, rich-structure,
and WeChat structural-fallback fixtures. This is an R2 parser change. Rollback
removes the stage from the ordered pipeline without a schema migration; callers
retain the classified failure and original-page recovery path.
