# ADR 0074: FreshRSS and Miniflux account sync

## Status

Accepted on 2026-08-06.

## Context

River needs to connect several self-hosted reader accounts without duplicating the same RSS source locally or mixing account-specific read/starred state. Credentials, server errors, and complete server URLs must not enter diagnostics.

FreshRSS documents its Google Reader compatible API as the preferred mobile/native integration and exposes subscription, stream, token, and edit-tag endpoints below `api/greader.php`. Miniflux documents feeds and entry state under its `/v1` API. River follows those public contracts rather than scraping either web interface.

References:

- https://freshrss.github.io/FreshRSS/en/developers/06_GoogleReader_API.html
- https://miniflux.app/docs/api.html

## Decision

- A feed-server account contains a stable local ID, provider kind, credential-free HTTPS base URI, and an opaque redacted credential.
- `FeedServerAdapter` is the provider-neutral boundary. Pulls return the complete subscription set, a bounded provider-appropriate state reconciliation set, and a monotonic integer cursor. State pushes are explicit and bounded. FreshRSS rechecks its bounded stream window so old items whose state changed are not hidden by their publication time; Miniflux uses `changed_after`.
- FreshRSS uses Google Reader authorization, `subscription/list`, `stream/contents/reading-list`, `token`, and `edit-tag`.
- Miniflux uses `X-Auth-Token`, `GET /v1/feeds`, incremental `GET /v1/entries`, and grouped `PUT /v1/entries` state updates.
- One canonical feed URL maps to one local source. Each account retains a separate `(account, remote feed)` mapping and separate remote entry state.
- Applying a pull checks the expected previous cursor and rejects regression. Older entry state cannot overwrite a newer state.
- Removing an account deletes only that account's cursor, mappings, and remote state. A local source is removed only after its final account mapping is gone.
- Diagnostics expose provider kind, stable account ID, counts, and cursor movement only. Credentials, response bodies, remote errors, and complete server/source URLs are excluded.

## Consequences

The pure-Dart adapters and in-memory reference repository can be replayed offline on every platform. A durable Drift repository and secure-storage account UI may implement the same ports later without changing protocol or mapping semantics.
