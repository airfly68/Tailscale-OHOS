# M10 Theme and resource governance

## Scope and ownership

M10 moves only repeated, user-visible semantic colors and text in the device
connection cards and shared Home traffic accent into resources. `base` remains
the default palette; `dark` supplies every color name with an equivalent dark
value. `zh_CN` supplies every base string name. The system remains the only
theme owner: no preference, setting, persistence field, or app-level theme
override was added.

`EntryAbility.applyEdgeToEdge` continues to update status and navigation bar
content colors from the current `Configuration` on creation, foregrounding, and
`onConfigurationUpdate`. Resource-qualified ArkUI colors update with the same
system color-mode transition. M10 originally retained the existing HDS
point-light action effects; M14 later removed them from `DeviceActionButtons`
in favor of three standalone normal rounded buttons after device review. The
sign-out confirmation explicitly uses the system primary
surface, preventing the platform fallback white dialog surface in dark mode
while retaining its existing cancel/destructive action flow.

The account sign-in action uses its paired semantic blue instead of the
platform emphasized fallback. The destructive sign-out action uses a
transparent surface with semantic red text and a system gray rounded border, avoiding both the
platform white fallback and a large saturated red fill while preserving the
existing enabled, disabled, loading, and destructive semantics.
The logged-out control-server edit action follows the same dark-mode treatment:
it has a transparent circular surface with a system-gray outline instead of a
platform white fill.

## Verification and rollback

`scripts/test.ps1 -Suite M10ThemeResources` parses the resource files, checks
both name-pair contracts, verifies targeted resource consumers and absence of
the replaced literals, and guards the existing system-bar hooks. The
device theme smoke probe launches the built HAP and observes the authenticated
Home, Transfer, and Settings shell in light mode, dark mode, then restored
system mode; the dark-mode sign-out confirmation is opened and cancelled
without sending a logout request. It makes no app preference or data change.

Rollback consists of removing the M10 color/string entries, fixture, suite, and
this document, then restoring the prior component literals. There is no new
theme persistence, route, protocol, backend, account, or user-data migration.
