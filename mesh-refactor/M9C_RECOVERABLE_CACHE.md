# M9C Recoverable cache and SecretStore boundary

M9C moves only new Taildrop send-side staging copies (`taildrop-outbox`) to
`context.cacheDir`. These copies are made from user-selected files solely for
one transfer request and are removed after completion/failure. The existing
`filesDir/taildrop-outbox` remains a legacy read root: the VPN Extension
accepts a queued request from either root and cleans only the root named by a
validated request. New cache cleanup never deletes the legacy root.

| Concern | M9C behavior |
| --- | --- |
| Existing/legacy staged send | New Extension accepts the old `filesDir` root, so an overlay upgrade can process its existing request without rewriting it. |
| New staged send | A new request uses `cacheDir`; request directory and destination must not already exist, and copied size/type plus non-symlink status is verified before the request is published. |
| Failed copy, verification, disk, or system call | The fresh cache request directory is best-effort cleaned. The legacy root and every authoritative file stay untouched. |
| Atomic handoff replacement failure | Existing IPC atomic-write code keeps the previous request/response intact and removes only its temporary file. |
| Cache clear/expiry | Covers cacheDir staging copies only; it does not traverse `tailscale`, control-server settings, login, IPC, history, legacy outbox, or remote Taildrop state. |
| Rollback | Legacy files and legacy read path remain. Rolling back does not require deleting cache data or logging in again. |

M9C does not migrate inbox exports because they can represent a user-visible
received-file save workflow. It does not move or parse tsnet state, does not
change IPC JSON fields, and does not create a SecretStore implementation.
`SecretStore.ets` is interface-only: no Asset Store, HUKS, encrypted-file,
identity, login, or persistence consumer is introduced.

Fault-injection coverage runs in a disposable test sandbox for an existing
target, interrupted copy, verification mismatch, failed replacement, simulated
disk-full/system-call cleanup, and cache-cleanup failure. Every injected case
asserts that a legacy sentinel is unchanged.

Fixture labels: existing target; copy interruption; verification failure;
atomic replacement failure; disk full; cache cleanup failure; system call failure.
