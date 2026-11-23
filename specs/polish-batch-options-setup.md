# Task: polish batch B, fix the tiny defects the audit found

The owner judges polish by tiny details at native size ("it's tiny things like this that really affect the quality of polish"). A read-only audit rendered every scene in both HUD styles at 1920x1080 and 5120x1440 and listed ranked defects in `C:/Users/leeba/.cache/kstyleui-evidence/audit-polish-muse/REPORT.md`, with 2x crops in its `crops/` folder. Read its caveats first (some backdrop content is not KstyleUI).

**Your rows**: #4 and #29 Options help and nav cut mid-sentence or half-clipped with no scroll affordance, #28 search results show two identical UNIT FRAMES headings and an orphan line, #30 live preview shows a plain black disc placeholder and unreadable microtype, #5 setup Welcome Medallions/Frames thumbnails tiny inside wide empty cards, #26 setup Layout page highlights DPS while the caption says Showing: Tank, #27 setup Modules page toggle columns drift because two-line help stretches rows in one column only.

For each row: reproduce it (render the scene the row names; confirm it's KstyleUI, not backdrop or a harness artefact; if a row turns out not to be real or only a fixture problem, say so and fix the fixture), find the cause, fix it so the element looks deliberate and finished, and keep one consistent style with its siblings. Some rows say "confirm whether this state exists in game": check the code paths and decide. Fixes that change today's look are fine (that's the point), but anything that changes behaviour gets an Options setting, on by default.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/polish-options-setup/`: for every row, a before/after 2x crop pair at 1920x1080 and 5120x1440 (Medallions and Frames where both apply), `--strict`, real backdrops; plus a zero-pixel diff for scenes your rows don't touch. Look at each crop yourself against the review checklist in `specs/_verify-audit.tmpl` ("Polish details").

**Files it may edit**: `KstyleUI_Options/**`, `Core/Setup/**` (no new top-level locals in Layouts.lua). PR #764 (setup/Options page fade fix) is in review and touches Core/Setup/Window.lua and KstyleUI_Options/Window.lua: rebase onto it once merged and keep its changes, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**` (fixtures and the guard allowlist only to remove entries).

**PR**: `fix(options-setup): polish details from the native-size audit` with `## Changelog` (`Fixed:` lines in player words), `## In-game checks`, and a table of rows: fixed / not real (why). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); several polish batches run in parallel in other modules, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the row table.
