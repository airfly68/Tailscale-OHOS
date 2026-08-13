# M4A VPN Command Lifecycle

This table defines the M4A boundary for the existing connect, secure-login,
disconnect, and fast-reconnect flows. The command gateway owns their Native,
VPN Extension, and command-file IPC. The existing BridgeStatus adapters remain
the UI compatibility entry points.

| Event / owner | Command state and action | Duplicate / stale completion rule |
| --- | --- | --- |
| Connect button | `stopped` -> `starting`; stage the unchanged VPN config then request the VPN Extension | A second connect is ignored while connect or disconnect is active; completions require the active command id. |
| Secure login button | `needs_login`; request and open the existing backend login URL | Concurrent login/connect commands are rejected; backend-start timeout becomes `timed_out`. |
| Disconnect button | `stopping`; retain the existing stop request/response files before stopping the VPN Extension | Duplicate disconnect is ignored; response and extension completion require the active command id. |
| Fast reconnect | Reuses the unchanged, bounded cached config and resumes `starting` | A stale cache or failed stage falls back to the existing backend preflight path. |
| UI foreground / background | UI visibility starts or stops presentation polling only; `APP_FOREGROUND_EVENT` refreshes health state | tab/page visibility never stops the core VPN or backend. |
| UIAbility lifecycle | `aboutToAppear` installs foreground observation; `aboutToDisappear` removes it and invalidates UI command completions | Lifecycle invalidation rejects late Promise, timer, and browser completions without stopping the core VPN. |
| VPN Extension lifecycle | The extension owns its backend watcher and stop cleanup through `onBackground` and `onDestroy` | Its start/stop requests remain idempotent and continue independently of page visibility. |
| Notification / process recovery | Existing EntryAbility foreground and VPN status recovery paths re-observe the extension | Re-entry must not start duplicate backend watchers or listeners; recovery callbacks use a captured lifecycle generation. |

Non-goals: exit-node selection, subnet/LAN settings, Tailsend, existing VPN
configuration strings/defaults/timeouts, Native/Go ABI, file names and JSON
shapes remain unchanged. `beginVpnConnection`, `openSecureLogin`, and
`stopVpnProbe` remain as compatibility adapters for rollback.
