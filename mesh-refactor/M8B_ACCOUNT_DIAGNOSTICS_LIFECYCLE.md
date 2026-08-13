# M8B Account and Diagnostics lifecycle

`AccountDiagnosticsGateway` owns the M8B account and diagnostic Native/file
boundary. Existing account-state fields, logout behavior, diagnostic report
input, event records, report cache/retention behavior, and first-run diagnostic
tools remain implemented by their existing compatibility services.

| Event | Owner and behavior | Idempotency / cancellation rule |
| --- | --- | --- |
| Account refresh | `BridgeStatus` maps the existing Account summary after `AccountDiagnosticsGateway.readAccount`. | The existing empty-account fallback and Huawei-brand normalization remain unchanged. |
| Logout | `AccountDiagnosticsGateway.logout` invokes the existing backend logout ABI. | `logoutInProgress` rejects a repeated request. Failure keeps the established logout status; only the current AccountDiagnosticsRequestGuard generation updates UI. |
| Diagnostic entry | `BridgeStatus` retains the existing hidden-entry counter and disclosure UI. | Entry does not start diagnostic work or change persisted settings. |
| Probe, report, and media self-test | The gateway owns bridge probes, diagnostic event files, report generation/share, and the report cache/retention implementation. | Separate generation guards cancel stale completion after a repeated entry or a destroyed feature host; a cancelled completion cannot update UI or share a stale report. |
| First-run reset, force stop, crash simulation | UI remains the confirmation owner; the gateway owns the diagnostic-only welcome-marker and stale-status file operations. | Diagnostic action generation is checked after every asynchronous VPN completion. A destroyed feature host cannot continue a reset or stage a simulated crash. |

M8B does not change log redaction, diagnostic report format, report/cache file
locations, Account UI layout, HTTP-risk UI, routing, protocol fields, or user
data formats. Those concerns remain outside this milestone.
