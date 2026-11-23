# Task: polish batch E, fix the tiny defects the audit found

The owner judges polish by tiny details at native size ("it's tiny things like this that really affect the quality of polish"). A read-only audit rendered every scene in both HUD styles at 1920x1080 and 5120x1440 and listed ranked defects in `C:/Users/leeba/.cache/kstyleui-evidence/audit-polish-muse-a/REPORT.md`, with 2x crops in its `crops/` folder. Read its caveats first (some backdrop content is not KstyleUI).

**Your rows**: #1 quest tracker counts 3/8 and 0/1 half outside the card border and the collapse chevron straddling the corner, #4 RestedXP guide arrow drawn as a plain white square (verify in game; may be a harness stand-in), #5 Frames quest card half empty with "6 more, scroll down", #16 RestedXP Guide Configurator header has three plain olive squares and the Speedrun Guide window is empty, #17 RestedXP arrow text prints over the Blizzard zone banner in game.

For each row: reproduce it (render the scene the row names; confirm it's KstyleUI, not backdrop or a harness artefact; if a row turns out not to be real or only a fixture problem, say so and fix the fixture), find the cause, fix it so the element looks deliberate and finished, and keep one consistent style with its siblings. Some rows say "confirm whether this state exists in game": check the code paths and decide. Fixes that change today's look are fine (that's the point), but anything that changes behaviour gets an Options setting, on by default.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/polish-skins-guides/`: for every row, a before/after 2x crop pair at 1920x1080 and 5120x1440 (Medallions and Frames where both apply), `--strict`, real backdrops; plus a zero-pixel diff for scenes your rows don't touch. Look at each crop yourself against the review checklist in `specs/_verify-audit.tmpl` ("Polish details").

**Files it may edit**: `KstyleUI_Skins/**` (tracker, quest card, RestedXP and Zygor skins only), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**` (fixtures and the guard allowlist only to remove entries).

**PR**: `fix(skins): polish details from the native-size audit` with `## Changelog` (`Fixed:` lines in player words), `## In-game checks`, and a table of rows: fixed / not real (why). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); several polish batches run in parallel in other modules, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the row table.
