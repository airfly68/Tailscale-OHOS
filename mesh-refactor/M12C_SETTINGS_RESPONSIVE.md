# M12C Settings responsive switching

## Scope

Settings, Account, and Diagnostics remain owned by `BridgeStatus`. M12C adds
one independent Settings content strategy:

- `<840vp`: one controlled-width column;
- `>=840vp`: two controlled-width columns;
- the existing `600vp` rule remains Shell navigation from M12A, and the
  Transfer `840vp` rule remains independently owned by M12B.

The content column keeps the existing `ResponsiveLayout.SETTINGS_CONTENT_MAX_WIDTH`
limit. The outer content wrapper is also bounded so a large window does not
stretch the Account, Preferences, or Diagnostics cards beyond the intended
reading width. No device-type, fold-state, orientation, `1440vp`, or ratio
branch was added.

Each Settings section keeps its heading and panel together. At the two-column
boundary, Account, network, appearance, storage, About, and the Diagnostics
disclosure occupy independent GridCol sections, with stable structural IDs for
the device probe. At smaller widths the same sections return to one column.

## State and continuity

`BridgeStatus` remains the sole owner of control-server input and confirmation,
appearance and Home-layout preferences, cache state, diagnostics unlock/
expanded state, and diagnostic report status. The layout builders do not add
task references, gateway calls, preference writes, or new component state.

The same `settingsScroller` is retained. When the Settings layout crosses
`840vp`, `currentOffset().yOffset` is captured before `layoutWidth` is updated.
After the layout pass, one lifecycle-generation-protected restore task applies
the difference with `scrollBy`. Repeated width events coalesce through
`settingsScrollRestoreTimer`; normal same-layout resizes do not schedule work.

The resize path does not submit unconfirmed settings, reload Preferences,
register/unregister observers, generate or share diagnostics, clear cache, or
open a system overlay. Existing Settings, Account, Diagnostics, and lifecycle
request guards remain unchanged.

## D014 overlay policy

The D014 Sheet/Dialog decision is still limited to the confirmed behavior. M12C
does not restore transient Sheet/Dialog/Alert references after a layout change;
the underlying `BridgeStatus` state remains intact. The fixture and static
contract test explicitly check this boundary.

## Verification and rollback

`mesh-refactor/fixtures/m12c/settings-responsive-contracts.json` covers the
`599/600/839/840/1439/1440vp` cases, `839→840→839` boundary continuity, stable
Settings state, scroll anchoring, request guards, and forbidden resize work.

The connected phone provides below-`840vp` evidence. Tablet and 2in1 evidence
is recorded as **not executed** when those targets are unavailable; no result
is inferred from the phone. No protocol, route, Preferences format, or user
data changes are introduced; there is no preference migration.

Rollback removes the Settings strategy, section wrappers, scroll-anchor
fields/restore task, M12C fixture/documentation, and suite registration. It does
not require preference migration or data cleanup.
