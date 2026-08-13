# M6A Tailsend receive lifecycle

`TaildropReceiveGateway` owns the existing receive request payloads, notification
action parsing/claiming, matching response check, and one-request remote-delete
claim. `BridgeStatus` remains the owner of picker/gallery/clipboard presentation,
preview, history, cache and restart-recovery behavior.

| Event | Required sequence | Duplicate/failure rule |
| --- | --- | --- |
| Notification Want (cold or hot) | `EntryAbility.handleTaildropNotificationWant` stores the existing action fields; Bridge matches it against the live inbox before saving. | The notification action key is claimed before dispatch, so a repeated Want cannot start another local save. |
| Receive | `stage` writes the unchanged request JSON and Extension validates/persists its result. | A result must match the current request ID and action. |
| Export/save | Local staged bytes are exported only after `staged`; text/media/file paths retain their existing user-visible flows. | Cancel or `export_failed` resets the operation and does not issue `delete`. |
| Remote deletion | A successful local save/copy requests `delete` only afterward. | `claimRemoteDelete` prevents the same request ID/name from deleting twice. Failed/offline deletion is recorded in the existing persisted pending-delete queue and retried with a new request ID. |
| Process termination | Existing inbox snapshot loading resumes only pending remote deletions. | No exported file is removed; a completed/failed delete cannot cause a second remote delete for the original request. |

No notification Want parameter, receive request JSON field, protocol file name,
local staging location, remote deletion timing, preview/history/cache reading, or
process-restart recovery format changes in M6A.
