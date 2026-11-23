# Task: damage and threat side by side for DPS, and the marketing pages say so

**Goal**: the owner: "an option to show threat when DPS, so the meter area shows 2 frames, 1 for damage and one for threat. Off by default: show damage, show threat or show both." #475 (merged, `KstyleUI_Meters/Settings.lua:253-269`) already has per-role choices (Damage, Threat, Both; DPS defaults to Damage) behind "Show the meter for my role". Make sure this works exactly as asked, then update the published pages.

**Target**: KstyleUI on latest `origin/staging`.

**Change**:
1. Check the DPS choice end to end: Damage (default) shows only the damage card, Threat only the threat card, Both shows two separate cards, damage and threat, placed cleanly together in every HUD style (Frames, Orbs, Medallions) and every layout (DPS, Tank, Healer) at 1920x1080 and 5120x1440 Spread: no overlap with each other or other HUD parts, both inside the screen, the same width, and meter bars keep full class colours. Fix only what fails, in the fewest lines. If a player has "Show the meter for my role" off (existing profiles), the manual "Show the damage meter" and "Show the threat meter" switches must give the same two-card result when both are on; check it.
2. Make the label say it plainly if it does not: the DPS row reads like "Meter while dealing damage: Damage, Threat or Both" with help "Both shows a threat card next to the damage meter." (strings.py sync).
3. Marketing: update `README.md`, `docs/store/curseforge.md`, `docs/store/wago.md` and the marketing pages `Tools/media/marketing.py` writes, with a short line on role meters (the meter follows your role: threat when you tank, damage otherwise; as DPS you can show damage, threat or both) and a profile per specialization. Add one new picture of the Both state (meter cards close-up) made by the render harness over a real game backdrop (`--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_NN.png`; never AI scenery), wired into `Tools/media/marketing.py` / `Tools/render/readme.py` the way the existing meter crop is, then rerun `python Tools/render/readme.py` and `python Tools/media/marketing.py --pages` and commit what they write. Keep the existing raid picture as it is (`docs/media/readme/frame_raid.jpg` and `docs/media/marketing/show_frame_raid.jpg`: restore them from staging if the scripts change them).

**Options**: no new setting unless step 1 shows one is missing; the DPS default stays Damage.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII addon files, one comment per TOC-loaded file, secret values, combat lockdown). Local checks per the speed rule below. Open a **draft** PR against `staging`: title `feat(meters): damage and threat side by side`, `## Summary`, `## Changelog` (`Added: As a damage dealer you can show the threat meter next to the damage meter (Options, Meters).`), `## In-game checks`, `## Before and after` (render paths).

**Files it may edit**: `KstyleUI_Meters/**` (except `Swing.lua`), `Core/Setup/Layouts.lua` (meter placement only, no new top-level local), `Core/Locales/**`, `README.md`, `docs/store/**`, `docs/media/**`, `Tools/media/**`, `Tools/render/**`, `Tools/regression/**`, `docs/feature-map.md`.

**Gate**: lint, python and the Meters/Layouts tests locally; green Mac CI is the full proof.

**Evidence of done**: tests for Damage/Threat/Both and the manual switches; renders of Both in each HUD style at 1080 and 5120x1440; the retaken pictures listed with one line each; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
