# Task: lazy default filling, pixel-identical

`test-perf-path-budgets` reload on staging is about 12.82M instructions against a 13.0M ceiling, and the remaining parity rounds keep adding settings. Find and remove reload cost with **no visual or behaviour change**.

- Profile the reload path under PUC Lua 5.1 (the harness's instruction counter): which modules and functions grew most since v0.2.8.2 (`git log v0.2.8.2..origin/staging`), especially default filling of new settings, per-frame Settings reads at build time, preview building, locale table work, and option-schema registration done eagerly that could be lazy (built when Options first opens).
- Fix the largest few with the smallest changes (lazy-build Options rows/previews, cache repeated lookups, skip work for features that are off). Do not raise the ceiling.
- Target: reload at least 400k instructions lower than staging, calls and regions not higher.

**Proof**: pixel-identical base-vs-PR renders (`--json-only` draw lists identical, plus PNG diffs 0) for hud_reference Frames, Orbs, Medallions, the Options pages and gallery scenes at 1920x1080 and 5120x1440; all module tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf` under PUC Lua 5.1; lint, python; hosted CI green. One PR to `staging`, `perf(core): ...`, `Changed:` line "KstyleUI loads faster after a reload". Do not merge.

**Files it may edit**: any addon file needed for the cuts, plus `Tools/regression/**`. No ceiling changes in `Tools/regression/test-perf-path-budgets.lua`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report before/after numbers, SHA and run id.

**This round's target (from #643's profile)**: default filling at load (`Core/Store.lua` checkDefaults/deepCopy/fill plus `Core/Fonts.lua` Fonts.Collect, about 335k instructions, driven by `Core/Options.lua` requiring every module's option defaults eagerly). Make it lazy or cheaper with identical saved data and identical reads: a profile must read the same values as today for every key, saved variables must serialise the same, and upgrades/migrations must behave the same (add a test comparing every Settings read before/after on a fresh and an upgraded profile). You may edit `Core/Store.lua`, `Core/Fonts.lua`, `Core/Options.lua`. Target: at least 250k lower reload than staging.
