# Task (polish): the Medallions target's aura timer is clipped by the portrait rim

In the Medallions HUD the target's leftmost aura timer text (e.g. '6s') loses its bottom pixels behind the target portrait's rim. Found in the marketing render hud_finish (review `C:/Users/leeba/.cache/kstyleui-evidence/marketing-refresh-034/verify-cd42ee92/report.md`, row 5); it is the addon's own aura row placement in `KstyleUI_UnitFrames`, so it shows in game too.

Fix it with minimal code so every aura timer and stack count on the Medallions target (and the player, focus and boss medallions if they share the code) sits fully clear of the portrait rim and any slab edge, at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, keeping the row's look and spacing otherwise. Check the Frames style is unaffected. Follow the repo rule: never read state back from regions inside engine aura buttons.

Add a regression in `Tools/regression/` that the timer text rect stays outside the portrait rim's rect; prove it fails first. Evidence: before/after 2x crops of the target's aura row at 1920x1080 and 5120x1440 in `C:/Users/leeba/.cache/kstyleui-evidence/fix-target-aura-timer-rim/`, pixel diffs limited to the aura row.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(unitframes): target aura timers clear the portrait rim` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
