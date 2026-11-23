# Task: v0.2.7 release blocker B1: the damage meter keeps spell names whole in Orbs Tank at 1440p

**Goal**: the v0.2.7 release-readiness review returned NO-GO. Fix blocker B1 on the latest `origin/staging`. The full review, with evidence paths, logs, crops and the bisect, is `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/readiness.md`; read the "B1" section and the evidence it cites.

**Scope**: Orbs Tank at 2560x1440 fails the strict guard: 'Lightning Bolt' is truncated in the damage meter (it needs 126.4 units and has 125.5). It passes at v0.2.6, and the likely source is the narrower side-by-side card from #500. Fix it so the name fits, with the smallest default change: card width, or the default meter layout in that one case. Keep the cards' shared width (one consistent style) and the nameplate-style rows. Check the meters at all sizes and styles.

**Rules**:
- Never move a saved position; change defaults only.
- `test-perf-path-budgets` must pass. Reload is at about 15.49M against 15.7M, so add near zero.
- The whole #504 overlap matrix and the `test-hud-reach-*` family must pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix, with a failure message that names the fix. Strict renders (`--strict`) of the affected scenes at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, compared with tag v0.2.6 where the review did.

**Constraints**: minimal code; CRLF/ASCII; locales synced if any text changes. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B1/`). Open a PR (not a draft) against `staging` titled `fix: the damage meter keeps spell names whole in Orbs Tank at 1440p` with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after`. Do not merge. **This blocks the release, so be fast.**

**Files it may edit**: `KstyleUI_Meters/**`, `Core/Setup/Layouts.lua` (defaults only), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
