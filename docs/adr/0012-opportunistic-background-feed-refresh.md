# ADR-0012: Opportunistic background feed refresh

Status: Accepted

River exposes one pure-Dart `BackgroundRefreshScheduler` contract and keeps
operating-system APIs in `river_platform`. Android and iOS use Workmanager
0.9.0+3, which delegates to Android WorkManager and iOS BGTaskScheduler.
Windows registers a current-user Task Scheduler entry that launches the same
River executable with `--river-background-refresh`. All registrations are
unique and update in place.

The schedule is explicitly opportunistic. Android enforces a minimum
15-minute interval and chooses a run window from device constraints. iOS uses
`BGAppRefreshTask`, fixes the rescheduling hint at one hour, and may delay or
skip execution according to system policy. Windows uses a minute trigger but
can only execute while the current user's scheduled-task context is
available. No River UI or API may describe these schedules as exact.

The platform callback starts a background Flutter isolate and builds a minimal
composition root. It opens the shared Drift database and the bounded HTTP
client but does not initialize WebView-based extraction. Existing durable feed
jobs are resumed first. A new batch is created only when no durable work is
pending, so an interrupted batch is not duplicated. Task results are returned
to the operating system so transient failures can be retried.

The default policy runs hourly, permits any connected network, and asks mobile
platforms to avoid low-battery execution. Wi-Fi and battery flags remain part
of the cross-platform contract. iOS treats them as advisory because
`BGAppRefreshTask` does not expose equivalent request constraints. Windows
records the selected policy while Task Scheduler owns the launch window;
fine-grained Windows network and low-battery enforcement belongs to the future
preferences slice.

The Windows native adapter validates the interval to 15-1440 minutes and never
passes user text to a shell. It launches `schtasks.exe` directly with a fixed
task name, a module-derived executable path, bounded values, and Windows CRT
argument escaping. Native tests cover quoting, and the Windows integration
smoke creates, queries, and deletes a real scheduled task.

Rollback is controlled by
`--dart-define=RIVER_BACKGROUND_REFRESH_ENABLED=false`. A disabled build
cancels the unique registration at startup and acknowledges stale callbacks
without reading user data. Removing Workmanager or the native Windows adapter
also requires first shipping a release that cancels existing registrations.
Foreground and manual refresh remain functional throughout rollback.
