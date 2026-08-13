# M6B Tailsend content lifecycle

`TaildropContentGateway` owns read-only parsing and validation for Taildrop
history, preview URIs, cache entries, and process restart recovery. It does not
write request files, send files, stage received files, or request remote deletion.

| Case | Required behavior |
| --- | --- |
| Cache missing / cache corrupted | The entry is excluded from restored cache state. The inbox remains authoritative and connected prefetch may recover the file; no remote delete is requested. |
| Process restart / recovery re-entry | Each restore has a generation. A superseded recovery cannot clear or overwrite a newer restored inbox. Pending deletes remain owned by M6A. |
| Application upgrade | Optional legacy preview/cache fields remain optional; valid history fields, order, retention, and inbox records are preserved. |
| Preview failure | A missing thumbnail produces no preview URI. The original cached/staged data remains available for the existing recovery path. |
| History missing | Missing or invalid history loads as an empty view only; it neither changes the inbox nor deletes history-media files. |

History and inbox fixtures retain their existing fields and ordering. The
unchanged `taildrop-send-request.json` and `taildrop-receive-request.json`
protocols, staging paths, remote-delete ordering, and persisted pending-delete
format remain under M5/M6A ownership.
