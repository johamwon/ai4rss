# ADR-0015: Durable offline article downloads

Status: Accepted

River represents an offline article download as a durable background job
instead of a transient reader action. The job payload stores only the bounded
article identifier. Current title, URL, Feed content, and metadata are loaded
from SQLite when the job runs, avoiding duplicate article bodies or private
content in the task table.

Jobs use a stable per-article idempotency key and the existing lease-based
queue. An expired lease is recoverable after interruption, retryable failures
use bounded exponential backoff, non-retryable failures stop immediately, and
an explicit user retry resets the attempt budget without creating duplicate
work. The coordinator serializes extraction jobs for now; the cached extractor
continues to enforce its own global and per-origin concurrency limits.

Network availability remains a best-effort link hint. An explicit offline
result leaves the job queued without making a request. App startup, foreground
resume, and an offline-to-online transition call the same idempotent resume
operation. `unknown` and `online` still attempt the bounded extraction request,
whose typed result is authoritative.

A successful job writes sanitized full text through the existing
`ExtractionCache`. Reader state derives offline availability from persisted
content as well as job state, so a cold database reopen displays the cached
article without requiring the task coordinator or network. The reader exposes
queued, downloading, available, and retryable-failure states with a single
offline action.

Rollback removes the reader action and coordinator wiring. Existing completed
job rows and cached article content are harmless, and no schema migration is
required.
