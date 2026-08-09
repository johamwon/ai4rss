# ADR 0072: IMA user-assisted portable interoperability

- Status: Accepted
- Date: 2026-08-06

## Context

River users want to move saved knowledge into Tencent IMA from Android, iOS,
and Windows. IMA publicly supports user-driven file and link import, but River
has no verified stable public API contract for native knowledge writes or a
documented private deep-link template. Binding to intercepted endpoints, user
cookies, undocumented schemes, or UI automation would be brittle and unsafe.

River already produces canonical Markdown and deterministic ZIP archives and
has system share, file picker, and safe external-URI adapters.

## Decision

Ship a portable, user-assisted integration:

- one item becomes one canonical UTF-8 Markdown file;
- multiple items or downloaded assets become one deterministic ZIP;
- the system share sheet sends that file only after an explicit user action;
- the system file picker can save the same package for manual import;
- “Open IMA” uses only the fixed public HTTPS entry `https://ima.qq.com/`.

The package is capped at 200 MiB, uses a safe leaf filename, carries an exact
SHA-256 content hash, and never exposes document content in diagnostics. Share
dismissal is distinct from unavailability. Plugin exceptions degrade to an
unavailable result and leave the River knowledge object untouched.

The contract exposes `usesNativePrivateApi == false`. It rejects custom schemes,
credentials, queries, fragments, non-IMA hosts, and private paths. No IMA token,
cookie, knowledge ID, or undocumented endpoint exists in the implementation.

## Consequences

- The workflow works across the three target platforms and degrades to ordinary
  Markdown/ZIP export if IMA is absent.
- The user must choose IMA in the system share sheet or complete import in IMA.
- River cannot report remote import completion because no stable public API is
  assumed.
- If IMA later publishes a documented stable API, a native connector can be
  added behind a separate provider-neutral port and the portable path remains
  the fallback.

## Verification

Unit and widget tests cover deterministic Markdown/ZIP, package limits, share
outcomes, plugin failure, public-entry allowlisting, user-facing actions, and
platform file metadata. A fixed five-case replay blocks private API or URI use
and verifies that diagnostics contain no private content.
