# Task: the consumables bar defaults to button size 26 with 0 spacing

The owner (2026-11-23): "the default value for consumables bar should be 26 with 0 spacing". Today `KstyleUI_ActionBars/Settings.lua` line ~117 has `defaults.consumables = { ... size = 19, ... spacing = -1, ... }` (-1 means "the HUD style's default spacing", `Core/Setup/Layouts.lua` `Layouts.ConsumableGrid`). He finds the bar far too small.

Change the defaults to `size = 26, spacing = 0`. Players who set their own size or spacing keep it (saved values win); players on the defaults get the new size. Then make sure the bigger bar still fits every layout without overlapping its neighbours: `Layouts.ConsumableFootprint`, the HUD fit and reach checks, both HUD styles (Medallions scales the size by `MEDALLIONS_SLOT`), DPS/Tank/Healer, centred and spread, at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, including saved positions. If 26 cannot fit somewhere, report where and what would have to move rather than shrinking it silently. Note the `placement` rows are disabled below size 30 (`Settings.lua` ~line 271): check whether that rule still makes sense.

Also the owner said "negative values for spacing don't appear to work": on the consumables bar -1 is a sentinel ("HUD default"), not an overlap. With 0 as the new default, make the slider honest: either let -1 mean what it says in the help text clearly, or drop the sentinel and allow 0 to 16 only. Pick the simpler one and say which.

Update the tests and render fixtures that assert the old 19/-1 values (derive new expectations from the code, never copy what the test prints). Evidence: renders of the HUD with the new default at all four sizes, both styles, in `C:/Users/leeba/.cache/kstyleui-evidence/consumables-26/`.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Setup/Layouts.lua` (no new top-level locals), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**PR**: `fix(actionbars): consumables bar defaults to size 26 with no gap` with a `## Changelog` `Changed:` line and `## In-game checks`. Do not merge. It ships in the next hotfix with the setup Welcome fix, so keep it small.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
