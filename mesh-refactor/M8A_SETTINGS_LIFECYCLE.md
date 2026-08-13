# M8A Settings and custom backend lifecycle

`SettingsPreferencesGateway` is the only M8A boundary for the existing
`control-server.json` data and the existing connected-home layout preference.
It delegates to the compatibility implementations without migrating fields,
defaults, file names, preference-store names, or confirmation semantics.

| Event | Owner and behavior | Idempotency / rejection rule |
| --- | --- | --- |
| Settings entry / repeated entry | `BridgeStatus` synchronously applies the existing control-server read, then starts a guarded layout-preference read. | `SettingsRequestGuard.begin()` gives each entry a new generation; only `isCurrent` may apply an asynchronous layout result. |
| Missing or legacy preference | The gateway delegates to the existing adapters. | Missing file, unconfirmed value, invalid URL, missing timestamp, and invalid layout value retain their existing defaults. |
| Custom backend confirmation failure | `BridgeStatus` preserves the existing connected, invalid-input, and storage-failure statuses. | No backend restart is requested when confirmation is rejected. |
| Confirmed changed backend | `BridgeStatus` retains the existing M4A `VpnCommandGateway` stop/restart flow. | A completion may restart only while its SettingsRequestGuard generation is current. |
| Destroyed feature host | `BridgeStatus.aboutToDisappear` invalidates SettingsRequestGuard. | A completion after a destroyed feature host cannot update UI or restart the backend. |

M8A adds no HTTP risk UI, Account/Diagnostics migration, file-location migration,
or visual redesign. The existing `ControlServerConfig` keeps first-run reset
ownership so its established tsnet cleanup behavior is unchanged.
