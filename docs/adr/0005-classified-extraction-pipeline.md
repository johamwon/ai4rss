# ADR-0005: Classified full-text extraction pipeline

Status: Accepted

Full-text extraction uses one domain request and one classified result contract.
Successful results include the extractor name, extractor version, quality score,
canonical URL, normalized metadata, sanitized HTML, plain text, and image URLs.
Failures use stable codes and attempt records; stage exceptions are converted to
`unexpected` failures instead of escaping into the reader UI or logs.

The local pipeline stops at the first trusted result. Its initial order is:

1. complete content supplied by the feed;
2. the static `mp.weixin.qq.com` adapter;
3. the temporary generic HTML fallback.

The generic fallback is not considered a Readability implementation. A formal
Readability stage and platform WebView stages can be inserted into the same
contract without changing consumers. All remote HTML crosses the shared
sanitizer before it becomes an `ExtractedArticle`.

This is an R2 parser and content-safety change. Its rollback boundary is the
ordered stage list: a faulty strategy can be removed or moved behind another
strategy without a database migration. Fixtures are synthetic and the harness
stores only expected structure, quality thresholds, and failure codes, never
copyrighted article bodies or credentials.
