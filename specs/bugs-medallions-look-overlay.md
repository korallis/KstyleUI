# Task: the Medallions look overlay overrides player choices

Pre-existing Medallions defect found during #695 (`C:/Users/leeba/.cache/kstyleui-evidence/medallions-defects/pr-695-possible-bugs.md`): the LOOK overlay re-applies a value whenever the player writes it back to the base default, so some choices cannot be made: party medallion off (`party.portrait = false`), raid names above (`raid.textLayout = ABOVE`), raid power, buff count, plate name outline NONE, `name.size` 16, `level.size`, `debuffs.size`. Also: options that ignore their default value (helper B report, `helper-B-report.md` beside it). Make every player choice stick (a value the player set, even equal to the base default, wins over the look) while the look still sets the defaults for untouched keys. Minimal change in the overlay; a test per listed key.

PR: `fix(settings): your choices win over the Medallions look`, `Fixed:` line.

**Rules**: minimal code, prefer deleting; Medallions pixel-identical to staging except where the fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, the module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `Core/**` (the settings/look overlay only), `KstyleUI_GroupFrames/**`, `KstyleUI_UnitFrames/**`, `KstyleUI_Nameplates/**` (only where they apply the look), `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.
