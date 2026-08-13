# M12A Home responsive switching

M12A confirms the D012 Home strategy using window content width and height,
not device identity:

| Window | Home content | Navigation input |
| --- | --- | --- |
| `<600vp` | Single column | Bottom |
| `600-839vp`, portrait | Single column | Bottom |
| `600-839vp`, landscape or square | Single column | Side |
| `>=840vp` | Master/detail | Side |

The 600vp and 840vp boundaries are the only adopted width breakpoints. The
320vp, 1440vp, 0.8, and 1.2 candidates are not adopted: the fixture tests
them as continuity cases and the production strategy does not branch on them.
The `>=1440vp` case keeps the expanded layout and its existing max content
width; it does not introduce new business content or density rules.

The existing Home read-only gateway, peer DTOs, selection key, VPN protocol,
and persistence remain unchanged. The master/detail and single-column lists
share one `Scroller`; the selected peer and the list's first visible index are
retained when a width or navigation change rebuilds the layout. Restoration is
in-memory and lifecycle-bounded; it does not persist a UI coordinate or issue
network, VPN, or Taildrop work.

The boundary fixture covers both sides of every adopted threshold and the
portrait/landscape distinction in the medium range. Device evidence is kept
in `STATUS.md` per connected form factor; unavailable tablet and 2in1 devices
are recorded as not executed rather than treated as passing evidence.

Rollback removes the M12A strategy methods, Home layout branch and scroll
anchor, fixture, suite registration, and this document. Existing Home content,
routes, protocols, persistence, and user data need no migration.
