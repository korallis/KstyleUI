# Task (bug, hotfix): crest pieces raise "forbidden object" errors

The owner's BugGrabber on v0.3.4.3 (Medallions, rogue):

```
1x KstyleUI_ActionBars/SlabMedals.lua:58: calling 'SetSize' on bad self (Attempt to access forbidden object from code tainted by an AddOn - Usage: self:SetSize(x, y))
[KstyleUI_ActionBars/SlabMedals.lua]:58: in function 'Even'
[KstyleUI_ActionBars/SlabMedals.lua]:474: in function 'Place'
[KstyleUI_ActionBars/SlabTrackers.lua]:229
[KstyleUI_ActionBars/SlabTrackers.lua]:434: in function 'Update'
[KstyleUI_ActionBars/Module.lua]:196 (OnSpells: the spells-changed handler)
[KstyleUI/Core/Events.lua]:38
```

and an older one recorded on v0.3.1 (same family, still worth checking on staging):

```
3x KstyleUI_ActionBars/SlabStorm.lua:253: calling 'SetAlpha' on bad self (Attempt to access forbidden object from code tainted by an AddOn - Usage: self:SetAlpha(alpha))
SlabStorm.lua:253 (Motion: cloud:SetAlpha) <- :260 Count <- :329 (event handler) <- Events.lua:38
```

Find out from the Forever client source (forever branch of Gethe/wow-ui-source, plus `Blizzard_APIDocumentationGenerated`) when a region KstyleUI created becomes a "forbidden object" for tainted code: which state makes the crest's medals and storm clouds forbidden (e.g. combat lockdown with the crest anchored to or parented under a secure or protected frame, a restricted anchor family, the "Restricted" state `Medals.Restricted()` already tests, a vehicle or pet battle, a cinematic). Then make every crest code path that writes to these regions (SetSize, SetPoint, SetAlpha, Show/Hide, texture changes) respect that state the way the rest of the crest does (`Medals.Locked()` / `Medals.Restricted()`): skip and queue the work, and apply it once the state ends (one owner per event in `Core/Events.lua`). Do not swallow the error with pcall. Check all crest files (`KstyleUI_ActionBars/Slab*.lua`), not just the two lines, and the OnSpells path in `Module.lua`.

Make the stub raise the client's forbidden-object error in that state (as `test-stub-refusals.lua` does for other refusals), and add a regression that fires SPELLS_CHANGED (and the storm's event) in that state, asserts no error and that the queued layout applies once it ends; prove it fails before the fix.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Events.lua` only if needed, `Tools/regression/**`.

**PR**: `fix(crest): no forbidden-object errors while the crest is locked` with a `## Changelog` `Fixed:` line and `## In-game checks` (state the trigger you found so the owner can reproduce it). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof (cite the file); Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
