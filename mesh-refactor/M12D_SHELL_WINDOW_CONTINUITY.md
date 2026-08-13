# M12D Shell window continuity and safe-area convergence

M12D makes the existing window responsibilities explicit without adding a
second layout owner:

| Responsibility | Owner | Contract |
| --- | --- | --- |
| Window edge-to-edge and visible system bars | `EntryAbility` through `WindowEnvironment.shellWindowPolicy()` | Window-level background can reach the system regions; status/navigation bars remain enabled. |
| Content safe-area avoidance | each page's HDS `HdsNavigation.titleBar` | `avoidLayoutSafeArea: true` and `enableComponentSafeArea: true` are used consistently by Home, Transfer and Settings. |
| Freeform system title area | the system window | The freeform title area stays visible and is not hidden or replaced by an application title-bar strategy. |
| Window inputs | `WindowEnvironment` | It remains the only owner of `windowSizeChange`, `avoidAreaChange` and density listeners. |

The stable `Index → AppShell → BridgeStatus` host keeps the current Tab,
selected peer, Transfer input/receive/send/cancel state, Settings state and
the existing Home/Transfer/Settings `Scroller` instances alive. The root
`onAreaChange` path is the equivalent window-size change test input for phone
landscape, tablet fullscreen and tablet split-screen, 2in1 free-window and fold open/close
when a foldable device is unavailable. It changes only layout metrics and the
already bounded scroll anchors; it does not issue a network, file, picker,
save, send, cancel or remote-delete action.
The continuity contract requires no repeated business action during any of
these window changes.

The foldable device itself is **not verified** in this environment; the
explicit evidence label is **foldable device not verified**. The
fixture records the equivalent window-size change cases, while `STATUS.md`
records unavailable tablet, 2in1 and foldable evidence as **not executed**.

M12D does not implement a Sheet/Dialog restoration strategy. The existing
connection Sheet/Dialog/Alert references are transient and **not restored**
across a layout rebuild; underlying BridgeStatus state remains authoritative.
This preserves the still-partial D014 decision and avoids retaining expired
overlay component references.

No protocol, no persistence format, route, AppStorage key or user-data format
is changed. Rollback removes the policy declaration, structural IDs, fixture,
suite registration and this document; the existing edge-to-edge and HDS page
behavior can be restored independently of business code.
