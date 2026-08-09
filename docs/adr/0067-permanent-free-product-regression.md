# ADR-0067: Permanent executable Free product boundary

## Context

An entitlement matrix alone does not prove that River remains useful when an
account or paid plan disappears. A later composition-root or UI change could
leave the key marked Free while still routing the feature through a cloud or
payment dependency. River's commercial promise therefore needs an executable
cross-package regression, not only policy tests.

The product decision on 2026-08-06 also postpones App Store, Google Play, and
Windows payment integration. Product completion must continue without making
local reading depend on those channels.

## Decision

1. COM-003 through COM-005 are deferred as payment-channel work. COM-006
   through COM-009 may be built later but do not block the local-first product
   and knowledge-intelligence milestones.
2. COM-010 is a permanent Fast Lane group covering three states: no account,
   expired Pro trial, and Pro-to-Free downgrade.
3. Every state executes six real local flows after the semantic Free Gate:
   synthetic WeChat full-text extraction, reuse of the extracted body without
   network, article speech segmentation for system TTS, Podcast RSS parsing,
   local `KnowledgeItem` creation, and complete Markdown ZIP export.
4. The replay must report zero network calls. It may use only synthetic checked-
   in fixtures and local deterministic implementations.
5. The group can be expanded but never removed, reduced to entitlement-only
   assertions, or made conditional on store configuration.

## Evidence

The fixed replay completes 18/18 feature-state checks: three WeChat
extractions, three offline reads, fifteen speech segments, three playable
Podcast episodes, three local knowledge items, and three portable export
bundles, with zero network calls.

## Consequences

Payment work can be resumed later without reopening the Free product boundary.
Any store, account, paywall, cloud, or knowledge change that breaks these flows
will fail PR Fast. Platform-specific system TTS and Podcast device behavior
remain covered by their existing integration and physical-device matrices.

## Rollback

Disable unfinished paid entry points. Do not remove the replay or route any Free
flow through a paid service. Preserve all local content and exports.
