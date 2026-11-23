# Task: v0.2.7 release blocker B3: data bar: a 14-unit default, and Right rail restores the old readout

**Goal**: the v0.2.7 release-readiness review returned NO-GO. Fix blocker B3 on the latest `origin/staging`. The full review, with evidence paths, logs, crops and the bisect, is `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/readiness.md`; read the "B3" section and the evidence it cites.

**Scope**: Two owner decisions.
(1) The default top bar height becomes **14 units** (the owner chose this). The design says a 14-unit bar fits the free top band with a top inset of 0, so the Frames HUD keeps its v0.2.6 Auto size at 2560x1440 and 5120x1440 (today it shrinks about 5% to the next step), and top elements (minimap, buffs, story cards) draw exactly where they did. Prove the Frames root width at 2560x1440 equals v0.2.6's (1950.5 units) and that top-anchored rects match v0.2.6. Players who raise the height in Options still get the inset as now. Update migration 41's default if it writes a height.
(2) **Right rail must restore today's readout.** After Setup.Apply (a new install or a re-run of /kstyle setup), choosing Right rail leaves the readout at top centre from the saved TOP 0 0; with rail chosen before Setup, it sits about 60 units high, under the tracked-buff column. Make Right rail place the readout exactly at v0.2.6's default rail spot (1752.5,181 at 1920x1080), clearing a top-bar position saved by the bar itself, but never one the player moved by hand. Test it after Setup.Apply in all three styles against v0.2.6 rects.

**Rules**:
- Never move a saved position; change defaults only.
- `test-perf-path-budgets` must pass. Reload is at about 15.49M against 15.7M, so add near zero.
- The whole #504 overlap matrix and the `test-hud-reach-*` family must pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix, with a failure message that names the fix. Strict renders (`--strict`) of the affected scenes at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, compared with tag v0.2.6 where the review did.

**Constraints**: minimal code; CRLF/ASCII; locales synced if any text changes. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B3/`). Open a PR (not a draft) against `staging` titled `fix: data bar: a 14-unit default, and Right rail restores the old readout` with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after`. Do not merge. **This blocks the release, so be fast.**

**Files it may edit**: `KstyleUI_DataBars/**`, `Core/Setup/**`, `Core/Layout/Layout.lua` (only if the inset needs it), `Core/Store.lua` (migration 41 default only), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
