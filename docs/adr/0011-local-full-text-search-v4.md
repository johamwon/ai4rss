# ADR-0011: Local full-text search and schema v4

Status: Accepted

Article search is a local-first capability behind the pure Dart
`ArticleSearchRepository` port. The adapter combines article title, author,
feed title, feed summary, extracted plain text, knowledge tags and knowledge
notes into an SQLite FTS5 virtual table. The trigram tokenizer supports
substring matching for Chinese and case-insensitive Latin text without a
server-side index. Queries with no usable trigram, including one- or
two-character Chinese terms and punctuation-heavy literals, use bound `LIKE`
parameters with escaped wildcard characters.

User text is never concatenated into SQL or interpreted as an unquoted FTS
expression. Result highlights are derived as literal ranges and rendered as
text spans, not HTML. Search terms, indexed bodies and snippets are not logged
or uploaded. The UI debounces input, replaces stale streams and limits each
result set to 200 rows by default.

Schema v4 adds the `article_search_index` virtual table and ten triggers.
Triggers rebuild affected index rows after searchable article changes, full
text cache writes, feed-title changes and knowledge-item changes. The
migration is additive and idempotent: if an interrupted upgrade already
created a partial index, opening v4 creates missing triggers and performs a
deterministic rebuild. Versioned fixtures cover v1, v2 and v3 upgrades, a
partially created v4 index and a populated current v4 database.

The performance gate seeds 10,000 articles, warms the query path and requires
end-to-end local search P95 below 500 ms. Tests also cover Chinese, English,
special characters, state filters, ordering, trigger refresh, stale-query
replacement, empty/error/retry states and safe highlighting.

A rollback must keep schema version 4, the virtual table and triggers. An older
UI may omit the search entry point, but no release may decrement
`user_version` or drop the index. Search can be disabled at the composition
root while the triggers continue maintaining forward-compatible local data.
