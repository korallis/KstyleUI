# Task: customisation batch 7: a layout per spec

**Goal**: the owner approved the customisation-parity plan. Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (batch 7 and the Profiles row) and `options-layout-spec.png` in that folder. Today a spec can switch the whole profile. Add an optional layout-only choice per spec: element positions swap while the look (every other setting) stays the profile's.

**Scope**:
- On the Profiles page's spec assignment, add an optional "Layout" choice per spec.
  - The default is "Profile's layout", which is today's behaviour.
  - A layout can be saved from the current positions and given a name.
- Switching spec applies that layout's positions after combat, through the existing out-of-combat profile-switch path and `Combat.Queue`.
- Export and import include these layouts only when the player chooses to include layout.

**Rules**:
- An absent key is today's behaviour, and no migration rewrites saved places.
- Schemas are built when the page opens, with near-zero reload cost.
- Protected moves wait for `Combat.Queue`.

**Tests**: assign, switch, switch back, switch in combat (deferred), delete a layout that's in use (falls back to the profile's layout), and export and import round-trip. Renders of the Profiles page at 1920x1080 and 3840x2160.

**Constraints**: minimal code; AGENTS.md rules; evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-7/`). Open a **draft** PR against `staging` titled `feat(profiles): a layout per spec` with `## Changelog` (`Added: Give each spec its own layout of frames and bars while keeping one profile's look.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge. Lua shard 1 may fail only on `test-perf-path-budgets` until #519 merges.

**Files it may edit**: `Core/Profiles.lua`, `Core/Specialization.lua`, `Core/Layout/**` (only the apply path for a named layout), `Core/Store.lua` (if a new account table needs a default), `KstyleUI_Options/**` (the Profiles page), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/statecharts/**` if a charted flow changes.

**Gate**: lint, python and the touched tests locally. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
