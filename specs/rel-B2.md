# Task: v0.2.7 release blocker B2: the Medallions quest card shows whole lines again

**Goal**: the v0.2.7 release-readiness review returned NO-GO. Fix blocker B2 on the latest `origin/staging`. The full review, with evidence paths, logs, crops and the bisect, is `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/readiness.md`; read the "B2" section and the evidence it cites.

**Scope**: The default Medallions quest card clips text at all four sizes: less than one quest shows, and the last line's descenders are cut above the folded footer, even with the Classic minimap frame. v0.2.6 showed the whole quest plus the next title. Bisect (see the review): about 10 units were already lost between v0.2.6 and 834f5840 (#485, #494, #504 and #498 touch this rail), and #509's crest minimap footprint made it worse. Restore at least v0.2.6's visible content: the card height and layout must show whole lines, never a partial line above the footer, at all sizes, with Crest medallion, Crest ring and Classic. Add a guard test that no quest card line is partly clipped, so the render guard catches it next time.

**Rules**:
- Never move a saved position; change defaults only.
- `test-perf-path-budgets` must pass. Reload is at about 15.49M against 15.7M, so add near zero.
- The whole #504 overlap matrix and the `test-hud-reach-*` family must pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix, with a failure message that names the fix. Strict renders (`--strict`) of the affected scenes at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, compared with tag v0.2.6 where the review did.

**Constraints**: minimal code; CRLF/ASCII; locales synced if any text changes. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B2/`). Open a PR (not a draft) against `staging` titled `fix: the Medallions quest card shows whole lines again` with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after`. Do not merge. **This blocks the release, so be fast.**

**Files it may edit**: `KstyleUI_Skins/Quests/**`, `KstyleUI_Minimap/**` (footprint only), `Core/Setup/Layouts.lua` (defaults only), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
