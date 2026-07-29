# ADR-0043: Knowledge library and Notion experience

- Status: Accepted
- Date: 2026-07-29

## Context

KB-006 supplied the durable Notion connector, but readers still had no product
path from an article and its annotations to a local knowledge item, no place to
browse that item, and no visible way to connect a workspace, choose a target,
observe export progress, or recover a failed export.

The local knowledge object must remain the source of truth. A browser, OAuth,
Notion, or file-picker failure cannot damage reading data or require a River
account.

## Decision

1. The reader builds one `KnowledgeItem` from the currently displayed,
   sanitized revision. It includes the article source, Markdown, sanitized
   HTML, every highlight, and each attached note. Repository source identity
   preserves the first River ID and makes repeated saves update one item.
2. Knowledge is a first-class application destination. Narrow windows navigate
   from list to detail; Windows-wide layouts keep a list and detail pane side
   by side. Local filtering covers title, source, author, labels, highlights,
   and notes without sending content off-device.
3. Detail views expose the original public URL, deterministic Markdown export,
   local summary/labels/annotations, the stored body, and Notion status. Empty,
   loading, deleted, unavailable, queued, running, succeeded, failed, and
   cancelled states have user-visible recovery paths.
4. `NotionWorkspaceExperience` is an application boundary over the OAuth
   controller, target catalog, connector, safe external-URL gateway, and target
   selection store. Widget tests replace it without network or platform
   globals.
5. Production Notion composition is enabled only when the HTTPS
   `RIVER_NOTION_BROKER_URL` compile-time value is present. The public client
   never receives the Notion Client Secret. An unset value removes only the
   Notion UI actions and durable connector worker; local knowledge and
   Markdown export remain available.
6. Authorization opens in the system browser. The completion field accepts
   only a bounded one-time code or a safe `river://oauth/notion` callback whose
   flow ID matches the pending flow. It is also the explicit recovery path
   when an operating system does not return focus automatically.
7. The selected target destination ID is stored through the existing
   device-bound secure key-value adapter. Tokens keep their separately
   versioned authorization envelope. Disconnect revokes authorization, clears
   both local values, and never deletes local knowledge or remote pages.
8. All Notion writes continue through `DurableKnowledgeExportManager`.
   The detail page observes its state stream and exposes manual retry and the
   returned external page URL. UI code never calls connector Create or Update
   directly.

## Consequences

- Android, iOS, and Windows share one knowledge and Notion state model.
- Local capture works in Free/local-only builds, including builds with no OAuth
  broker configured.
- Target selection survives application restarts but is cleared on disconnect.
- Search in this slice is an in-memory view over the watched local collection;
  the existing FTS index remains the scalable global-search path.
- Rollback consists of omitting `RIVER_NOTION_BROKER_URL`. Queued jobs and
  external mappings remain in local storage and can resume when composition is
  re-enabled.

## Evidence

- Widget tests cover list/detail layouts, local filtering, Markdown export,
  authorization, target selection, token redaction, export failure, retry, and
  external-page opening.
- Controller tests cover safe callback parsing, mismatched flow rejection,
  target restoration, disconnect, and authorization cleanup.
- The Windows integration journey executes:
  article → highlight/note → local knowledge → selected Notion target →
  successful durable export state.
