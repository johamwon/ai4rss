# ADR-0061: Cloud extraction SSRF boundary

## Status

Accepted for CLOUD-002 core on 2026-08-06.

## Context

Cloud full-text rescue fetches a user-selected public article from a server
network that may also reach metadata services, loopback, private subnets, and
other internal infrastructure. Checking a URL string or resolving a hostname
once is insufficient: redirects can target private hosts, DNS answers can mix
public and private addresses, and DNS rebinding can change an answer between
validation and connection. Compressed or redirect responses can also multiply
memory, bandwidth, and parser work.

## Decision

1. `CloudFullTextRescueService` accepts only absolute HTTP/HTTPS URLs up to
   4,096 characters, without credentials or fragments. Ports are restricted to
   the scheme defaults. Local/reserved hostname suffixes are blocked and DNS
   names must use bounded ASCII labels; international names must arrive as
   canonical punycode.
2. Literal and resolved IPv4/IPv6 addresses are parsed without permissive
   legacy forms. Loopback, unspecified, link-local, private, carrier-grade NAT,
   benchmarking, documentation, multicast, reserved, IPv4-mapped, NAT64,
   unique-local, and non-global IPv6 ranges are rejected. Every answer in a DNS
   set must be public; a mixed public/private set fails closed.
3. DNS and transport are separate injected ports. After validation, the core
   selects one deterministic public address and passes it to a pinned transport.
   That adapter must connect to exactly that address while retaining the
   original hostname for HTTP Host and TLS SNI/certificate validation. It must
   disable automatic redirects and secondary DNS lookup. The response reports
   the connected address, which the core compares byte-for-byte after parsing.
4. Every redirect is resolved relative to the current URI, validated again,
   and given a fresh DNS resolution. HTTPS-to-HTTP downgrade, credentials,
   private targets, loops, missing/oversized Location, and more than three
   redirects are rejected. Redirect bodies count toward the same total byte
   budget.
5. Defaults allow 2 MiB per response, 3 MiB across the redirect chain, eight
   DNS answers, eight seconds per DNS/transport hop, and twenty seconds total.
   DNS time is deducted before the transport deadline. Declared Content-Length,
   actual decoded bytes, response-header size, and cumulative bytes are checked
   independently. A production adapter must enforce the request byte bound
   while streaming and after content decoding, not buffer an unlimited body.
6. Only `200 text/html` or `application/xhtml+xml` with UTF-8 is parsed. Other
   status codes, media types, malformed encodings, transport failures, and
   extraction failures map to stable bounded codes. Retry-After is accepted
   only for retryable upstream failures and is capped at one hour.
7. Successful bytes enter the existing static layered extractor, which applies
   the WeChat adapter or Readability and always runs the HTML Sanitizer. Scripts,
   frames, forms, executable attributes, dangerous protocols, SVG/MathML, and
   active embedded content cannot reach the returned article.
8. Request/response diagnostics expose only a host hash, scheme, path-segment
   count, address family, status, header names, byte counts, and time/size
   limits. Hostnames, paths, query values, resolved addresses, HTML, article
   metadata, cookies, credentials, and internal transport errors are excluded.

## Verification

- Unit tests cover local hostnames, credentials, non-default ports, IPv4/IPv6
  special ranges, mixed DNS answers, connected-address mismatch, same-host DNS
  rebinding, private redirect, HTTPS downgrade, redirect loop/limit, declared,
  actual and cumulative oversize, DNS/transport timeout, total-deadline
  subtraction, unsupported media, malformed encoding, malicious HTML, and
  diagnostic privacy.
- The deterministic Harness fixes five release attacks: private literal,
  private redirect, DNS rebinding, oversized response, and malicious HTML.
  Private literals perform zero transport calls; all successful content is
  sanitized before release.
- Unit and Harness lanes use injected DNS/transport only and never access the
  real network.

## Rollback

Disable the cloud-extraction entitlement or remove the rescue adapter from the
cloud composition root. The client continues through feed content, site
adapter, local Readability, cached content, platform WebView, and opening the
original URL. No local database migration or user-content deletion is involved.
