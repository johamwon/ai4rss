# ADR 0075: Feed transport, compatibility, and image proxy hardening

## Status

Accepted on 2026-08-09.

## Context

The initial feed transport handled timeouts, redirects, UTF-8/Latin-1, and byte limits, but did not explicitly test compressed bodies, broader legacy encodings, or DNS results. Feed compatibility coverage was too small to enforce the PRD's 99% parser gate. Sanitized article images still pointed directly at publisher hosts.

## Decision

- Production feed HTTP resolves every initial and redirected host, rejects empty, excessive, mixed, private, loopback, link-local, reserved, documentation, multicast, and IPv4-mapped private answers, then connects a direct socket to a validated address while preserving the TLS hostname. This closes the DNS-rebinding gap. The client still disables automatic redirects and drops validators on cross-origin redirects.
- `gzip` and `deflate` are decoded as streams, and the configured response limit applies to expanded bytes. Unknown or stacked content encodings fail closed.
- Charset decoding adds pinned pure-Dart GBK/GB2312, Big5, Windows-1251/1252, and Latin-2 codecs. UTF-16, GB18030, and unknown declarations remain rejected rather than decoded approximately.
- The parser has explicit document/item limits, accepts RSS 1.0/RDF aliases by namespace URI, handles Dublin Core and Content Module aliases, resolves `xml:base`, preserves Atom XHTML, inherits Atom feed authors, and drops unsafe item/resource URIs.
- The offline compatibility gate generates 100 stable minimized cases across RSS 2.0, RSS 1.0/RDF, Atom, and JSON Feed and blocks below 99%. It complements real-site canaries without archiving copyrighted feed bodies.
- The WeChat static gate generates 40 stable structural variants and blocks below 95%.
- `HttpsImageProxyPolicy` rewrites only public-looking, credential-free, default-port HTTPS images into a fixed proxy origin with a URL-safe encoded source path. HTTP, local-looking, credential-bearing, oversized, and non-image resources are rejected. The selected policy changes extractor cache versions. Production enables it only when `RIVER_RESOURCE_PROXY_URL` is supplied; otherwise the existing direct-image behavior remains available.
- The proxy service is responsible for decoding the source path, public DNS pinning, redirect revalidation, media signature checks, byte/time limits, quotas, and cache policy. Those server controls cannot be weakened by client HTML.

## Consequences

The client remains deterministic and offline-testable while production deployments can prevent direct publisher image requests. A configured image proxy must be deployed and operated as a hardened fetch service; River does not silently route images through an undocumented third party.
