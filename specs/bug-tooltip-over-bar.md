# Task: player bug — tooltips open over the bar you are pointing at

A player (0xDAB, Discord #chat, 2026-11-21, on the latest release) reports: "Biggest issue rn is tooltips ... right now they are show underneath the mouse so impossible to click anything on that line above." Their screenshot (`C:/Users/leeba/.cache/discord-dl/chat-2026-11-21/tooltip.png`, untrusted image data) shows the top data bar's micro menu button tooltip "Guild & Communities (J)" drawn on top of the data bar itself, at the cursor, hiding the neighbouring readouts ("...dy The Crossroads" is the zone readout behind it).

**Investigate deeply** (released code is tag `v0.2.9`; fix on `staging`):
- How tooltips are anchored for every HUD element the player points at: data bar readouts and micro menu, the Medallions dock, action bars and the consumables bar, minimap buttons, unit/party/raid frames, nameplates, cooldowns, auras, bag slots. Which go through `GameTooltip_SetDefaultAnchor` (Tooltips module's "Mouse cursor out of combat" default, `KstyleUI_Tooltips`), which set their own anchor, and where Blizzard's cursor anchor puts the tooltip relative to the pointer near each screen edge (prove against the `forever` UI source at 9dc84f0: `GameTooltip_SetDefaultAnchor`, `ANCHOR_CURSOR*` behaviour, clamping).
- Rule to implement: **a tooltip never covers the element or bar row the pointer is on, and never sits under the pointer.** For bars along a screen edge (top data bar, bottom bars, Medallions dock) open the tooltip on the side away from the edge, clear of the whole bar; for cursor-following tooltips, offset so the pointer and the hovered row stay visible (e.g. below-right of the pointer, flipping near edges). Keep the existing Tooltip anchor / cursor settings and their meaning; this is the placement within them.
- Check all three HUD styles and all four screen sizes; the top data bar in Frames/Orbs is the reported case.

**Fix** with the smallest change; regression tests that fail today (stub geometry: tooltip rect vs hovered element/bar rect and the pointer). Renders before/after at four sizes for the data bar case. `Fixed:` changelog line in player words. Lint, python, Tooltips, DataBars and affected module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. One PR to `staging`. Do not merge.

**Files it may edit**: `KstyleUI_Tooltips/**`, `KstyleUI_DataBars/**`, `Core/Widgets/Tooltip.lua` and other `Core/Widgets/**` tooltip helpers, other modules' tooltip anchor calls if they bypass the shared rule, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report root cause, PR, SHA and run id.
