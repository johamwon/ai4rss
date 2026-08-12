# 0077 Chinese typography and local custom fonts

## Context

River previously inherited Flutter's generic platform typography while the reader kept a partial hard-coded fallback list. Chinese glyphs, punctuation, mixed Chinese/Latin text, and emoji could therefore resolve differently between the application shell and article content. Users also had no way to use a font for which they already hold a licence.

## Decision

- The design system owns explicit platform-aware Chinese sans-serif and serif fallback stacks. Windows prefers Microsoft YaHei UI, Apple platforms prefer PingFang SC, and Android/Linux prefer Noto Sans CJK SC. Traditional Chinese, Latin, and emoji fallbacks remain in every stack.
- The application permits an explicit user action to import one local `.ttf` or `.otf` file of at most 32 MiB. Font collections are not accepted.
- The platform repository validates the extension, SFNT signature, byte limit, and SHA-256 digest before storing a font. The runtime family alias is derived from that digest rather than the user-controlled filename.
- A custom font is loaded with Flutter's `FontLoader` before it becomes active. Its metadata and hash-named bytes are written atomically under the application support directory and verified again during startup.
- Imported font bytes and filenames remain local. River does not upload, sync, or include them in logs and diagnostics. The settings UI states that the user is responsible for the font licence.
- If a persisted font is missing or corrupt, River falls back to the platform Chinese stack and provides an explicit recovery action. Restoring defaults removes only River-managed font files.

## Consequences

- Chinese typography is consistent across navigation, settings, lists, and the article reader without bundling a licensed font or increasing the installer size.
- Exact glyph shape and metrics still vary where platforms do not ship the preferred family; the ordered fallback stack makes that degradation explicit.
- Custom fonts are device-local and must be imported separately on each device.
- Flutter cannot unload a runtime font family before process exit. Restoring the default stops using the family immediately, while its engine allocation is released when the application exits.

## Evidence

- Design-system tests pin the primary family and fallback order for Windows, Apple, and Android platforms.
- Platform filesystem tests cover valid TTF/OTF import, malformed and collection rejection, corruption detection, redacted diagnostics, atomic restore, and scoped cleanup.
- Widget tests cover import, preview, app-wide theme rebuilding, restore-default, and startup recovery.
- Existing reader Golden tests remain part of the Fast Lane to detect typography regressions across phone, tablet, and Windows layouts.
