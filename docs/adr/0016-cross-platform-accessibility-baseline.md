# ADR-0016: Cross-platform accessibility baseline

Status: Accepted

River treats system accessibility settings and non-pointer navigation as part
of the primary reading path. The app provides explicit light and dark
high-contrast themes generated at the maximum Material contrast level and
wires them to Flutter's system high-contrast selection. A reader preference
for explicit light or dark mode preserves that preference while still applying
the system high-contrast request.

The home and reader surfaces use reading-order focus traversal. Windows
primary actions are available without a pointer: `Ctrl+F` searches, `Ctrl+N`
adds a feed, and `Ctrl+R` refreshes. In the reader, `Ctrl+M`, `Ctrl+S`,
`Ctrl+L`, `Ctrl+O`, and `Ctrl+D` control read state, starred state, read-later,
open-original, and offline download; `Ctrl+R` retries failed full-text
extraction. Shortcuts call the same guarded controller operations as visible
buttons, so disabled, mutating, and retry states remain consistent.

Interactive article rows expose one consolidated button node with a stable
title, source, metadata, and text status. Reader titles are semantic headings.
Loading, failure, extraction, network, and offline states continue to pair
icons with readable text and live-region announcements, rather than relying on
color alone.

Automated coverage verifies critical high-contrast color pairs at WCAG AA
4.5:1, semantic button/header flags, keyboard activation, primary shortcuts,
and a narrow article list at 200% system text size. Existing reader layout
goldens retain phone, tablet, and Windows dimensions plus large-text coverage.
TalkBack, VoiceOver, and Windows keyboard checks remain release-device
acceptance gates because widget semantics cannot reproduce every native
screen-reader behavior.

Rollback removes the shortcut wrappers and high-contrast theme bindings.
Semantic labels and text-plus-icon status presentation remain safe to keep.
