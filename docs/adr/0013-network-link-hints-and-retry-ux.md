# ADR-0013: Network-link hints and explicit retry UX

Status: Accepted

River exposes a pure-Dart `NetworkMonitor` contract. The production adapter
uses `connectivity_plus` on Android, iOS, and Windows, while tests inject a
deterministic monitor. Feature and domain packages do not import the plugin.

The reported state describes only whether the operating system sees an active
network transport. An `online` result does not prove Internet or feed
reachability because captive portals, DNS failures, proxies, and server
failures remain possible. River therefore uses an explicit `offline` result
only to avoid an obviously futile request. `unknown` and `online` both permit
normal bounded requests, whose typed failures remain authoritative.

When a user adds a source while offline, River keeps the validated URI in
memory, displays a persistent accessible offline banner, and performs no
network request. Reconnection presents an explicit retry action using the
same URI, so the user does not need to paste it again. Failed discovery also
keeps the URI and offers retry without exposing transport exceptions.
Subscription persistence remains idempotent and is still owned by
`FeedRefreshService`.

Manual refresh follows the same model: an obviously offline attempt is held in
memory and can be retried after reconnection. Foreground automatic refresh
checks the hint before starting and is reconsidered after the link returns.
Operating-system background constraints remain the primary control for
headless work.

Pending UI actions are intentionally process-local. Durable feed refresh jobs
remain in the existing persistent queue, while an unsubmitted address must not
be silently persisted as a subscription. A future draft-subscription feature
may add encrypted persistence with an explicit data model.

Rollback removes the `ConnectivityNetworkMonitor` production injection and
falls back to `UnknownNetworkMonitor`. All requests then retain their existing
timeout and typed-error behavior; no stored data or migration is involved.
