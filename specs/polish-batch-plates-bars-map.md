# Task: polish batch D, fix the tiny defects the audit found

The owner judges polish by tiny details at native size ("it's tiny things like this that really affect the quality of polish"). A read-only audit rendered every scene in both HUD styles at 1920x1080 and 5120x1440 and listed ranked defects in `C:/Users/leeba/.cache/kstyleui-evidence/audit-polish-muse/REPORT.md`, with 2x crops in its `crops/` folder. Read its caveats first (some backdrop content is not KstyleUI).

**Your rows**: #7 nameplate cast row x-misaligned with the health row, #32 nameplate level text in a different place and colour per plate and a fill tick past its track, #8 crest travel flyout drawn over by debuff icons and MOUNTS half covered, #12 '-' and '=' keybind labels float outside their sockets, #13 procced cooldown glow border thicker than siblings and stack counts placement, #15 minimap coordinates plaque straddles the ring and the zone plaque overhangs, #16 open tracking grid covers the minimap and its buttons sit half outside the ring, #17 empty black minimap disc state, #9 world map texture bleeds to the window edges and pane bottoms unequal, #31 item level numbers half outside the gear icon corner.

For each row: reproduce it (render the scene the row names; confirm it's KstyleUI, not backdrop or a harness artefact; if a row turns out not to be real or only a fixture problem, say so and fix the fixture), find the cause, fix it so the element looks deliberate and finished, and keep one consistent style with its siblings. Some rows say "confirm whether this state exists in game": check the code paths and decide. Fixes that change today's look are fine (that's the point), but anything that changes behaviour gets an Options setting, on by default.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/polish-plates-bars-map/`: for every row, a before/after 2x crop pair at 1920x1080 and 5120x1440 (Medallions and Frames where both apply), `--strict`, real backdrops; plus a zero-pixel diff for scenes your rows don't touch. Look at each crop yourself against the review checklist in `specs/_verify-audit.tmpl` ("Polish details").

**Files it may edit**: `KstyleUI_Nameplates/**`, `KstyleUI_ActionBars/**` (not Totems.lua), `KstyleUI_Cooldowns/**`, `KstyleUI_Minimap/**`, `KstyleUI_Skins/**` (world map and character only), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**` (fixtures and the guard allowlist only to remove entries).

**PR**: `fix(plates-bars-map): polish details from the native-size audit` with `## Changelog` (`Fixed:` lines in player words), `## In-game checks`, and a table of rows: fixed / not real (why). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); several polish batches run in parallel in other modules, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the row table.
