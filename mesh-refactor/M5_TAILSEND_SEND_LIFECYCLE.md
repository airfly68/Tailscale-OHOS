# M5 Tailsend send lifecycle

The UI owns only document/media picker presentation. `TaildropSendGateway` owns
send-side copied-file preparation and cleanup; the existing request ID, staged
outbox paths, preview, cancel request, retry semantics, and Extension delivery
protocol remain unchanged. Late picker/preparation completion is rejected by the
existing active-send guard, so one user action cannot enqueue duplicate sends.
