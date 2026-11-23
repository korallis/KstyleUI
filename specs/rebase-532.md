# Task: urgently rebase PR #532 (reload headroom) onto staging

**Goal**: staging (dbaf2956) is now **over** the reload budget at 15,713,800 against 15,700,000, after #509, #514 and #523 merged. PR #532 (branch `korallis/perf-cut-reload-cost`, head aec646c4) cuts about 328k by making the options registrations and previews lazy. It conflicts with staging in `Core/Setup/Layouts.lua`, `KstyleUI_Minimap/Settings.lua`, `KstyleUI_Nameplates/Module.lua`, `KstyleUI_Nameplates/Settings.lua` and `KstyleUI_Skins/Module.lua`, because those merges added new option rows: text formats, the minimap frame and restyling addons.

**Do**:
- Rebase onto the latest `origin/staging` and resolve every conflict, keeping both sides: the new rows from staging, built lazily the way #532 does it.
- Make sure the new staging rows (the Minimap frame choice, Skins restyleAddons, Nameplates text and filter rows) are lazy too.
- Prove `test-perf-path-budgets.lua` passes on the rebased branch with margin (target 15.4M or less), and zero changed pixels on the gallery and HUD scenes at 1920x1080 and 5120x1440 against staging.

**Tests**: `test-perf-path-budgets`, every touched module's settings and options tests, and `test-options-search`, under PUC Lua 5.1.

**Constraints**: minimal; CRLF/ASCII. Force-push with lease to the same branch. Do not merge. **This blocks every PR, so be fast.**

**Gate**: lint, python and those tests. Send worker_done as soon as it's pushed with local proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and reload count.
