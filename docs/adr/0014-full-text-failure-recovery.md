# ADR-0014: Safe full-text failure recovery

Status: Accepted

River keeps already-sanitized Feed or cached content readable when full-text
enhancement fails. A typed public failure code, retryability flag, and bounded
extractor attempt metadata are retained in reader state; private exception
messages and article content are not retained as diagnostic data.

The recovery surface offers four explicit actions. Readers can continue with
the available content, force a full-text reparse, open the canonical article in
the system browser, or share a user-initiated diagnostic report. A forced
retry bypasses a stale extraction result through the existing
`forceReparse` contract. When no readable fallback exists, the reader shows a
stable recovery state instead of an indefinite progress indicator.

Opening the original article is represented by a domain port. The production
adapter uses the platform URL launcher in external-application mode and
accepts only credential-free HTTP(S) URIs with a host. Unsupported or failed
launches become a safe `unavailable` outcome rather than exposing plugin or
operating-system errors.

Problem reports contain only the canonical URL, stable failure code,
retryability, and extractor name/version/outcome tuples. They exclude article
body text, notes, credentials, stack traces, and private failure messages. The
normal share gateway remains the user-controlled handoff, so River never sends
the report automatically.

Rollback replaces the production external-URI adapter with
`UnavailableExternalUriGateway` and hides the recovery controls while keeping
the existing extraction and cache behavior. No stored data or migration is
involved.
