# Task: customisation batch 1: text options and tag formats

**Goal**: the owner approved the customisation-parity plan (EllesmereUI-level customisation, inside one consistent style). Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (the gap table, "Shared building blocks" and batch 1), plus the mockups in that folder. Build batch 1.

**Scope**: One shared `TextRows` builder (font defaulting to the role font, size, outline, colour mode, format) and a tag painter that parses a format string, such as `[name]`, `[hp]`, `[hp:pct]`, `[hp:abr]`, `[pp]`, `[level]` or `[absorb]`, from the report's list where Forever has the data. It only calls SetText and never compares secret values. Wire it into unit-frame name and health text and nameplate name and health text. Today's presets stay the default format strings. Cache the parsed format per string and do no work per frame beyond today's updates.

**Rules for every batch**:
- An absent key is today's look; no migration rewrites a saved setting or place.
- Option schemas are built when the page opens, never at reload. Add near-zero reload cost; `test-perf-path-budgets.lua` must not grow.
- No comparison of or arithmetic on secret values; hand them to `SetText` or `SetValue` only.
- Protected changes wait for `Combat.Queue`.
- One consistent style: colour modes stay class, reaction, accent and custom.

**Tests**: behaviour tests for each new option, including off and default. Default renders are pixel-identical to base at 1920x1080 and 3840x2160. Add renders of the new options in use at all four sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160).

**Constraints**: minimal code; AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-1/`). Open a **draft** PR against `staging` titled `feat(options): text options and tag formats` with `## Changelog` (`Added: Text options for unit frames and nameplates: font, size, outline, colour, and your own text format such as [hp:abr] / [hp:pct].`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge. Lua shard 1 may fail only on `test-perf-path-budgets` until the staging reload fix (#519) merges; say so if it does.

**Files it may edit**: `Core/Options.lua`, `Core/Widgets/**` (the shared text builder only), `KstyleUI_UnitFrames/**`, `KstyleUI_Nameplates/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the touched modules' READMEs.

**Gate**: lint, python and the touched modules' tests locally. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
