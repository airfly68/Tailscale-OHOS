# M7 AppShell lifecycle

`pages/Index` creates one `AppShell`, which contains one stable feature host:
`BridgeStatus`. Changing a tab updates the existing HDS tab selection inside
that host; it does not recreate the host, restart the backend, discard an
unsubmitted input, or add another listener.

| Event | Owner and behavior | Idempotency / rejection rule |
| --- | --- | --- |
| Cold start | `EntryAbility.onCreate` registers `VpnBackgroundTaskManager`, validates the initial Want through `AppShellIntentAdapter`, queues its resulting action until `pages/Index` finishes loading, then delivers it. | Existing AppStorage keys remain the only handoff. `appShellContentReady` and `pendingAppShellFeatureActions` prevent the initial action from being emitted before the feature host can subscribe. Missing or invalid action fields do not create a Feature action. |
| Hot start / repeated Want | `EntryAbility.onNewWant` uses the same adapter. | A repeated Want key is delivered once per Ability lifetime; M6A retains the receive-side `claimNotificationAction` guard. |
| Notification open/save/later | The adapter accepts only the existing actions plus a safe file name and non-negative safe-integer size. | Invalid fields are rejected without logging their values. `open`/`later` remain tab navigation; `save` remains the existing M6A action. |
| Tab round trip | `BridgeStatus` remains mounted while HDS changes tabs. | `aboutToAppear`/`aboutToDisappear` are page lifecycle events, not tab lifecycle events; switching tabs does not stop the core VPN. |
| Background / foreground | `EntryAbility` owns the background task and emits `APP_FOREGROUND_EVENT` on return. | The AppShell does not stop the core VPN, transfer, or background task. |

Moonlight Wants and HosPlayer URIs retain their existing outbound launchers and
parameter validation. M7 adds neither `NavPathStack`, deep links, route
parameters, Feature HARs, nor visual changes.
