# ADR-0004: Durable feed refresh coordination

Status: Accepted

Foreground and future platform-scheduled feed refreshes use the shared
`BackgroundJob` store before network work begins. A refresh batch is idempotent,
lease-based and recoverable after process interruption. The coordinator runs at
most four jobs globally and at most two requests per origin, while ordering jobs
round-robin across origins to avoid one large subscription source monopolizing
the workers.

Cancellation is cooperative: queued work is cancelled immediately and an HTTP
request that already started may finish safely, but its late completion cannot
overwrite the persisted cancelled state. On application startup, the single
active coordinator requeues unfinished feed-refresh leases and resumes them.

Job payloads contain only the feed identifier and canonical URL. Failures use
bounded error codes; article bodies, credentials and response bodies never enter
the queue or logs.
