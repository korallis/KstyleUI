# Task (v0.3.5): three small polish follow-ups

1. **RestedXP Guide Configurator rows** (skin, RestedXP 4.11.39): RestedXP's 40-unit icon covers the skin's full-width tile hairlines by 3 units. Start the skin's tile 22 units in, where RestedXP starts its own background, so the icon reads as a badge (the skin's `Chrome.lua` Option path). Evidence: 2x crops at 1920x1080 and 5120x1440.
2. **Loot-roll window off-grid regions**: the loot-roll window has 14 off-grid regions against 12 allowed on staging (pre-existing). Snap them to whole pixels with the existing pixel helpers and lower the allowance to what remains (ideally 0).
3. **Zygor errors**: the owner's BugGrabber showed `ZygorGuidesViewerForever/ActionBar.lua:421` nil arithmetic and an ADDON_ACTION_BLOCKED. Find whether KstyleUI's Zygor skin (or action bars) causes them (taint path, a frame KstyleUI re-anchors or resizes that Zygor reads). If it does, fix it with minimal code and a regression; if not, report the evidence and leave the code alone. Never fight the other addon.

One PR, a commit per item. **Files it may edit**: `KstyleUI_Skins/**`, `Core/Widgets/**` only if a pixel helper needs it, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(skins): RestedXP rows, loot-roll pixels and the Zygor check` with a `## Changelog` `Fixed:` line per player-visible fix and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
