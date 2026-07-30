# ADR 0053: Explicit consent for local reading behavior

## Status

Accepted for PREF-004.

## Context

PREF-003 made behavior capture local-only and durable, but a storage default of
enabled cannot distinguish an informed choice from a new installation. Local
storage reduces exposure but does not remove the need to explain what is
recorded, what is excluded, and how to stop or remove it.

The same experience must work on Android, iOS, and Windows without adding an
account, network call, analytics SDK, or platform-specific consent state.

## Decision

1. Absence of the v15 singleton settings row means the introduction has not
   been acknowledged. In that state `ReadingBehaviorSettings` is
   capture-disabled and `record` returns `captureDisabled`; no event is written.
2. Production schedules one non-dismissible introduction after the first frame.
   The reader must choose either `暂不开启` or `仅在本机启用`. Either choice is
   saved locally, so the prompt does not repeat after restart. Back navigation
   is treated conservatively as disabled.
3. The introduction and settings page state, in user-facing language, which
   interactions may be recorded, that data remains on this device, and that
   article bodies, titles, URLs, notes, and AI content are excluded. They never
   claim anonymous upload or cloud processing.
4. A permanent `阅读偏好与隐私` entry is available from the main toolbar on all
   three clients. It exposes capture state, retention, versioned JSON copy,
   and an independently confirmed secure clear.
5. Turning capture off affects future writes only. Clear explains that it does
   not delete subscriptions, articles, favorites, notes, or knowledge items.
6. The UI depends only on `ReadingBehaviorRepository`, `Clock`, and an
   injectable export-copy callback. No network or upload dependency is present.

## Evidence

- Repository tests prove a missing row requires introduction and rejects event
  insertion; a saved disabled choice remains disabled.
- The app-shell widget test proves the first launch cannot continue without an
  explicit local choice and that declining is persisted.
- Privacy-page widget tests verify the complete local-only/excluded-data
  explanation, a named toggle semantic with state, enable confirmation,
  retention changes, injected JSON export, and destructive-clear confirmation.
- Domain, data, and app static analysis report zero issues.

## Accessibility and understanding checklist

- The dialog title asks a direct yes/no question and both actions describe the
  resulting state; there is no preselected checkbox or ambiguous `继续`.
- Local-only and excluded-data statements are available as one screen-reader
  semantic region.
- The capture control exposes the semantic label `本地阅读偏好记录`, toggled
  state, and spoken value `已开启` or `已关闭`.
- Color is not used to communicate capture state or destructive scope.
- All actions use standard Material focus, keyboard, and minimum target
  behavior shared by Android, iOS, and Windows.

## Consequences and rollback

This amends ADR 0052's unacknowledged enabled default without changing schema
v15. Existing persisted choices are preserved; only a missing row changes from
enabled to disabled. A rollback must retain the same missing-row gate or disable
capture globally. Removing the prompt while restoring an implicit enabled
default would be a privacy regression.
