# ADR-0042: Notion OAuth and managed page content

- Status: Accepted
- Date: 2026-07-29

## Context

River must connect a user's Notion workspace without shipping the public
connection's client secret in Android, iOS, or Windows binaries. It must also
recover from a crash after Notion created a page but before River persisted the
external mapping, and it must update River-owned content without deleting
notes that the user adds directly in Notion.

The current Notion API version is `2026-03-11`. Databases and data sources are
separate resources, new pages use a `data_source_id`, block appends use a
`position` object, and trash state uses `in_trash`.

## Decision

1. River's client calls an HTTPS OAuth broker. The broker creates a ten-minute
   flow with a one-time state, receives Notion's callback, performs the Basic
   authenticated token exchange server-side, and returns a two-minute,
   one-time completion code through the `river:/oauth/notion` app link. Access
   and refresh tokens never appear in a browser redirect.
2. The server kernel receives its clock, code generator, state/grant store and
   Notion upstream adapter through injection. Production must use a durable,
   atomic consume operation for state and completion grants. The Notion client
   secret exists only in the server composition root or secret manager.
3. The client stores the resulting authorization in
   `flutter_secure_storage`: Android Keystore, iOS device-only Keychain, and
   Windows DPAPI. Values use a versioned envelope; corrupt or future values are
   reported and are not silently deleted. A single 401 triggers one refresh
   through the broker and atomically replaces the stored authorization.
4. Target discovery paginates the official Search endpoint for pages and data
   sources. Destination IDs encode the target kind so a database ID cannot be
   confused with a data source ID.
5. Data source targets require a `rich_text` River ID property. River adds only
   this missing property, uses the actual title property's schema name, and
   maps optional source, URL, author, dates, topics, and AI summary properties
   only when compatible columns already exist.
6. Before creating a data-source row, River queries the River ID property. This
   closes the crash window between a successful remote create and the local
   external mapping commit. A page-parent target uses a deterministic
   SHA-256-derived River marker in the child title and keeps the full River ID
   in managed content. Matching duplicate rows are reduced to the
   lexicographically stable page ID, which also converges simultaneous creates
   from two devices when either device observes both rows.
7. River owns one top-level Toggle block in each page. Updates trash only prior
   River Toggle blocks, insert a replacement at the start, and append mapped
   blocks in batches of at most 100. Sibling blocks created by the user are
   preserved. A retry replaces a partial Toggle and converges.
8. Rich text is split below 2,000 characters, each append contains at most 100
   blocks, total generated blocks are bounded, and transport responses are
   bounded. Provider bodies, tokens, article text, and raw URLs are never added
   to failures or logs.

## Consequences

- Data source targets provide the strongest and fastest remote idempotency and
  are the recommended default.
- Page-parent recovery performs bounded Search calls and displays a short River
  marker in the generated child page title.
- Replacing the managed Toggle costs extra list/trash/append requests, but
  preserves user-authored sibling blocks and gives retries a clear ownership
  boundary.
- The broker kernel is deployment-platform neutral. A production deployment
  still needs durable state/grant storage, rate limiting, origin policy,
  observability without secrets, and secret-manager wiring.
- Rollback can disable Notion composition without affecting local knowledge
  objects or queued connector failures. Existing Notion pages remain owned by
  the user.

## Evidence

- Notion authorization:
  <https://developers.notion.com/guides/get-started/authorization>
- API version changes:
  <https://developers.notion.com/guides/get-started/upgrade-guide-2026-03-11>
- Data source query and filters:
  <https://developers.notion.com/reference/query-a-data-source>
- Page creation:
  <https://developers.notion.com/reference/post-page>
- Block append and request limits:
  <https://developers.notion.com/reference/patch-block-children>
  and <https://developers.notion.com/reference/request-limits>
