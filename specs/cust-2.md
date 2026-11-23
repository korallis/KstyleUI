# Task: customisation batch 2: show in party, raid or solo

**Goal**: the owner approved the customisation-parity plan (EllesmereUI-level customisation, inside one consistent style). Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (the gap table, "Shared building blocks" and batch 2), plus the mockups in that folder. Build batch 2.

**Scope**: Add party, raid and solo (plus their negations only if they're a few lines) to the shared Shown list every Layout element has (`Core/Layout/README.md`, Shown rules), using the existing state-driver path, so secure elements switch in combat through the driver and not through addon code. Prove it from Forever's `RegisterStateDriver` and macro-condition support (`[group:party]`, `[group:raid]`), citing the source.

**Rules for every batch**:
- An absent key is today's look; no migration rewrites a saved setting or place.
- Option schemas are built when the page opens, never at reload. Add near-zero reload cost; `test-perf-path-budgets.lua` must not grow.
- No comparison of or arithmetic on secret values; hand them to `SetText` or `SetValue` only.
- Protected changes wait for `Combat.Queue`.
- One consistent style: colour modes stay class, reaction, accent and custom.

**Tests**: behaviour tests for each new option, including off and default. Default renders are pixel-identical to base at 1920x1080 and 3840x2160. Add renders of the new options in use at all four sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160).

**Constraints**: minimal code; AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-2/`). Open a **draft** PR against `staging` titled `feat(options): show in party, raid or solo` with `## Changelog` (`Added: Show any element only in a party, in a raid, or when solo.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge. Lua shard 1 may fail only on `test-perf-path-budgets` until the staging reload fix (#519) merges; say so if it does.

**Files it may edit**: `Core/Layout/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the touched modules' READMEs.

**Gate**: lint, python and the touched modules' tests locally. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
