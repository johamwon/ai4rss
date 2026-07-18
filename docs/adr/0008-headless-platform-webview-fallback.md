# ADR-0008: Headless platform WebView extraction fallback

Status: Accepted

River adds a pure Dart `DynamicPageRenderer` domain port after the feed content,
source adapter, and static Readability stages. The production adapter uses
`flutter_inappwebview` headless mode, which delegates to Android WebView, iOS
WKWebView, and Windows WebView2 without placing a platform view in the reading
UI. Platform SDK types remain inside `river_platform`.

The renderer accepts only HTTP(S), applies a twelve-second default timeout, caps
the returned HTML at five MiB, limits main-frame navigations, blocks local URL
schemes and popup windows, and disables file/content access, geolocation,
third-party cookies and automatic media. JavaScript stays enabled
because this stage exists specifically for script-generated article bodies.
Rendered HTML is never stored directly: it is parsed by the existing
Readability stage and passed through the shared sanitizer first.

This is an R3 platform-channel and extraction-pipeline change. Dart contract
tests cover validation, timeout, size bounds, error mapping, stage ordering, and
attempt history. A local-HTTP integration smoke test exercises real script
execution and is runnable on Android, iOS, and Windows; the nightly Windows
journey executes it automatically. Merge and release builds compile all three
platform implementations. The plugin requires NuGet for its Windows WebView2
adapter, so every Windows workflow installs it explicitly.
The Windows application also defines Microsoft's narrow experimental-coroutine
compatibility macro for the transitive CppWinRT header used by WebView2; all
other compiler warnings remain errors.

Rollback removes `DynamicPageExtractionStage` from the composition root and
restores the static extractor version map. Existing cached articles remain
compatible because dynamic results use a distinct extractor id and version.
No database rollback is required.
