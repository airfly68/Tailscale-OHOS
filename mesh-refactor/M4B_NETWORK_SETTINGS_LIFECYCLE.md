# M4B Exit Node and Network Settings Lifecycle

M4B keeps the existing `routeAll`, `exitNodeAllowLANAccess`, and
`exit-node-choice` protocols unchanged. It only changes ownership of their
read/write completion handling. Every serialized queue retains the latest user
choice, so an earlier Native completion can never replace it.

| User action | Serialization / completion rule | Connection rule |
| --- | --- | --- |
| Select or clear an exit node | A per-setting queue serializes writes and retains the latest stable node ID. A completion changes visible state only when its generation remains current. | A pending exit-node write completes before the existing connect preflight continues. |
| Change subnet-route acceptance (`routeAll`) | The `routeAll` queue has its own idempotency generation, so a late result cannot overwrite a newer toggle value. A failed change can be retried by issuing the same setting again. | Pending writes finish before VPN connect; defaults and config strings are unchanged. |
| Change exit-node LAN access | The LAN-access queue is independent from `routeAll`, preserving the backend's masked-preference behavior and JSON field shape. | Pending writes finish before VPN connect; a disconnect never cancels an already requested persisted setting. |
| Backend snapshot / reconnect | Snapshots do not overwrite a setting while its queue is active. The existing backend restore applies the persisted fields and exit-node selection. | Reconnect observes the final persisted choice, never an obsolete UI completion. |

The old UI controls and Native method names remain available through
`NetworkSettingsGateway`; no route defaults, VPN configuration strings,
Tailsend behavior, persistent field names, or Native/Go ABI are changed.
