# M12B Transfer responsive switching

M12B gives Transfer its own content strategy while keeping the existing Shell
navigation strategy from M12A. Transfer uses only the `840vp` width boundary:

| Window width | Transfer content |
| --- | --- |
| `<840vp` | Single column: targets, inbox and history flow vertically |
| `>=840vp` | Split content: targets and activity sections are shown side by side |

The `600vp` boundary continues to control the already-verified Shell navigation
only. Transfer does not add a direction branch, an xl branch, a device branch,
or a fold-status branch.

## Ownership and continuity

`BridgeStatus` remains the single owner of the send and receive state, text
editor input, progress, cancellation, picker state, notification action claim,
and pending remote-delete state. The responsive builders contain no task
owners, gateway instances, component references, or persistence writes.

The same `transferScroller` is used in both layouts. When the content mode
crosses `840vp`, the current vertical offset is captured before the size state
changes. A single lifecycle-scoped restore task runs after the new layout is
bound and uses `scrollBy` to apply only the difference between the saved and
current offsets. Repeated window callbacks coalesce into one restore task;
destroyed hosts cannot run it.

Layout changes do not invalidate a send or receive request, reset progress,
cancel an active operation, reopen a picker, save a file, send a request, or
issue a remote delete. The existing `taildropPickerOpen`, preparing/receive
guards, notification claim, current-receive check, and remote-delete claim
remain authoritative. Send cancellation additionally returns immediately once
the cancel request is already pending.

## Verification

The strategy fixture tests both sides of `840vp`, continuity at `1440vp`, and
the `839→840→839` transition. It also checks that the retained user input,
receive state, progress and cancel state stay owned by `BridgeStatus`, and that
the existing notification, picker, save, send, cancel and remote-delete guards
remain present.

The M12B suite, the full local suite, ArkTS build, diff whitespace check and
the structural user UI probe are required. Phone evidence is recorded when a
device is connected; unavailable tablet and 2in1 targets are recorded as not
executed rather than treated as passing evidence.
Unavailable device targets: not executed.

No protocol or persistence format changes are introduced. No persistence
fields are added; routes and user-data formats remain unchanged.

## Rollback

Rollback removes the Transfer strategy, scroll-anchor restore, cancel guard,
fixture, suite registration and this document. Existing Taildrop gateways,
request files, history, inbox cache and user data require no migration.
