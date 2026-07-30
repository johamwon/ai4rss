# ADR 0048: Manual AI summary reader experience

## Status

Accepted for AI-005.

## Context

FR-AI-001 requires an explicitly requested, structured article summary while
FR-AI-004 forbids automatic paid calls for every unread article. The reader is
also progressively enhanced: a short Feed preview may be replaced by extracted
full text after an AI request starts or completes. AI failure, cancellation,
offline state, and stale output must never replace or block the readable body.

The client supports BYOK on Android, iOS, and Windows. Before a request, the
user must know which provider and model receive which content. A cached result
must remain useful offline without contacting that provider.

## Decision

1. `ArticleSummaryExperience` is the application boundary used by the reader.
   Its inspection operation resolves the secure BYOK profile, performs
   long/short routing, and reads validated cache only. It never contacts a
   provider. Generation is a separate explicit operation.
2. `ByokArticleSummaryExperience` composes the secure configuration vault,
   bounded OpenAI-compatible transport, Drift artifact repository, persistent
   long-summary checkpoints, network monitor, and injected clock. It routes to
   map/reduce only when the deterministic chunk planner produces multiple
   chunks.
3. Opening the reader panel performs cache-only inspection. Before generation,
   the panel displays provider, model, title/body scope, normalized character
   count, and maximum provider-call shape. A modal confirmation is required for
   every provider attempt and states that the user's provider may charge usage.
4. The reader owns a generation counter. Closing or cancelling the panel and
   replacing the article body invalidate adoption of late results. The current
   provider contract cannot abort an HTTP request already sent, so cancellation
   stops waiting and UI adoption; a valid late result may still complete through
   shared orchestration and enter the local cache. The UI states this boundary.
5. Each accepted summary records the normalized body SHA-256. A body replacement
   retains the old summary only as visibly stale and offers explicit
   regeneration. Stale output is never written into a knowledge snapshot.
6. Loading, idle, generating, ready, stale, cancelled, offline, unavailable,
   and failed are secondary reader states. The article body remains mounted in
   all of them. Errors expose only stable local codes and recovery actions.
7. A current summary contributes its full structured value, topics, and
   entities when the article is saved to the local knowledge library. Existing
   knowledge metadata is preserved when no current summary is available.

## Evidence

- Reader widget tests cover disclosure and confirmation, structured rendering,
  cancellation with a late provider result, retry, stale output after full-text
  replacement, offline recovery, cache-only restore, and knowledge inclusion.
- Application orchestration tests prove offline cache restoration, offline miss
  short-circuiting before transport, and stable missing-configuration failure.
- The existing AI schema, provider replay, long-summary, and validated-cache
  suites remain unchanged and green.

## Consequences and rollback

Manual AI now has a production composition path without enabling automatic
summaries or silent paid traffic. Secure BYOK configuration remains optional;
an absent or unreadable profile produces a local recovery state.

Feature rollback stops passing `articleSummaries` to `ArticleReaderPage`. The
reader, TTS, annotations, offline content, and knowledge library continue to
operate, while AI artifacts and checkpoints may remain on disk for a later
reenablement.
