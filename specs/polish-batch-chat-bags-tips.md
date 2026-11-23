# Task: polish batch C, fix the tiny defects the audit found

The owner judges polish by tiny details at native size ("it's tiny things like this that really affect the quality of polish"). A read-only audit rendered every scene in both HUD styles at 1920x1080 and 5120x1440 and listed ranked defects in `C:/Users/leeba/.cache/kstyleui-evidence/audit-polish-muse/REPORT.md`, with 2x crops in its `crops/` folder. Read its caveats first (some backdrop content is not KstyleUI).

**Your rows**: #3 chat edit box is a detached hairline strip (remove its guard allowlist line once fixed), #36 longest chat line has zero right padding and loot '+' markers misplaced, #37 sibling chat windows disagree on tab names, #20 bag stack counts render as two stacked numbers spilling past the socket, #21 a headerless 8-icon bag grid floating at top centre, #22 tooltip CURRENTLY EQUIPPED label straddles the border and 'You' over the bar end, #23 data bar values not in a column and XP/Honour the same purple, #35 aura timers in no order, one with a decimal, expiring timers low-contrast red.

For each row: reproduce it (render the scene the row names; confirm it's KstyleUI, not backdrop or a harness artefact; if a row turns out not to be real or only a fixture problem, say so and fix the fixture), find the cause, fix it so the element looks deliberate and finished, and keep one consistent style with its siblings. Some rows say "confirm whether this state exists in game": check the code paths and decide. Fixes that change today's look are fine (that's the point), but anything that changes behaviour gets an Options setting, on by default.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/polish-chat-bags-tips/`: for every row, a before/after 2x crop pair at 1920x1080 and 5120x1440 (Medallions and Frames where both apply), `--strict`, real backdrops; plus a zero-pixel diff for scenes your rows don't touch. Look at each crop yourself against the review checklist in `specs/_verify-audit.tmpl` ("Polish details").

**Files it may edit**: `KstyleUI_Chat/**`, `KstyleUI_Bags/**`, `KstyleUI_Tooltips/**`, `KstyleUI_DataBars/**`, `KstyleUI_Auras/**`, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**` (fixtures and the guard allowlist only to remove entries).

**PR**: `fix(chat-bags-tips): polish details from the native-size audit` with `## Changelog` (`Fixed:` lines in player words), `## In-game checks`, and a table of rows: fixed / not real (why). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); several polish batches run in parallel in other modules, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the row table.
