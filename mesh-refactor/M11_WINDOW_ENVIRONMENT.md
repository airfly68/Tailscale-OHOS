# M11 passive WindowEnvironment

`WindowEnvironment` is the only owner of the Entry window's
`windowSizeChange` and `avoidAreaChange` listeners and of that window's
UIContext `densityUpdate` listener. `EntryAbility` forwards configuration
updates to it and attaches/detaches it with the WindowStage lifetime.

It copies the initial window rectangle, system/navigation-indicator avoid
areas, and all three density values. Later callbacks copy only the value
delivered by their own event: a size callback does not fetch avoid areas, an
avoid-area callback does not fetch window properties, and a density callback
does not fetch a window value. `getObservation()` exposes a defensive copy for
a future responsive-layout milestone; M11 has no consumer that selects a page,
navigation model, or business action from it.

`attach()` is idempotent for the same live window and tears down the previous
window before replacing it. `detach()` first disables callbacks, unregisters
the same named callback references, and resets its listener count to zero, so
late callbacks after a destroyed WindowStage are ignored. The callbacks perform
no AppStorage write, file I/O, network request, timer, VPN, or Taildrop action.

The contract suite verifies listener ownership, matching unregistration,
configuration forwarding, passive callback bodies, and the three-listener
baseline. Device evidence is captured only for connected form factors; an
unavailable phone, tablet, or 2in1 is recorded as not executed rather than as a
passing result. Rollback removes this adapter, its EntryAbility lifecycle calls,
fixture, suite registration, and this document. Existing layout remains the
only behavior path and no route, protocol, storage, or user-data migration is
involved.
