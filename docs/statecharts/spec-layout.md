# Specialization layouts

Profiles > Active profile pairs each specialization (or assigned role) with a profile and an optional named layout. The page builds these rows when opened. No assignment means **Profile's layout**. Named layouts are account-wide snapshots of anchor, X and Y only; size, scale, visibility, opacity, strata and module settings stay with the selected profile. Saving takes the current positions, and editing positions while a named layout is applied updates that layout. Layout Mode undo and cancellation retain their existing behavior.

```mermaid
stateDiagram-v2
    [*] --> Settled : login checks the current spec
    Settled --> Requested : spec changes or current assignment changes
    Requested --> Waiting : Combat.Queue during combat
    Waiting --> Waiting : later events share the pending settlement
    Waiting --> Applying : combat ends, read the latest spec
    Requested --> Applying : out of combat
    Applying --> Profile : use the assigned profile
    Profile --> Named : named layout exists
    Profile --> Default : layout assignment is absent or deleted
    Named --> Settled : overlay positions and refresh Layout
    Default --> Settled : clear the overlay and refresh Layout
    Settled --> Deleting : delete an applied named layout
    Deleting --> Default : Combat.Queue settles, if the same layout is still applied
    Settled --> Default : disable specialization switching, after combat
```

`Core/Specialization.lua` settles through its existing single queued check, then calls `Layout.ApplyNamed` through `Combat.Queue`. Layout keeps the profile's saved places intact. Its merged entry view reads and writes named positions while other fields read and write the profile. A manual profile change clears the overlay; the next specialization change selects its assignment again. Deleting a name clears every character's reference and queues removal of that overlay only if it is still applied, preserving manual profile choices and later spec changes.

**Include layout** in Share defaults on. Turning it off exports settings only and preserves the receiving profile's positions and named layouts on import. Layout-only exports include the named layout library; module-only shares exclude it. Imports merge the library, preserving a conflicting existing name by giving the incoming layout a numeric suffix. Character specialization assignments stay private. `test-spec-layouts.lua` covers these paths at 1920x1080, 2560x1440, 5120x1440 and 3840x2160; `options_setup` with `RENDER_PAGE=Profiles` renders the page.
