# Task: v0.2.7 release-readiness review of staging (read-only)

**Goal**: the owner authorised publishing v0.2.7 overnight, but only if everything is good. Review the current `origin/staging` as a fresh, independent reviewer. Two PRs (#530 and the Medallions layout PR) will land after you start; review everything else now, and say which parts need a recheck once those land.

**Check** (cite evidence; renders go in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/`, never committed):
1. **Renders:** Medallions, Frames and Orbs, for DPS, Tank and Healer, at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160 (`Tools/render/shoot.sh hud_reference` with `--strict`; see AGENTS.md "App driver"). Look at every picture for overlaps, clipping, things off screen, and anything that breaks the one consistent style (sibling elements must match). Also render the data bar (top and Medallions dock), the consumables bar, the crest minimap (all three choices), the extra-bar presets C and D, and the Options window.
2. **Every new option off gives today's look:** for each option added since v0.2.6, compare a default-off or old-choice render against tag v0.2.6 where applicable.
3. **Upgrade:** a v0.2.6 profile, built from tag v0.2.6's Store defaults with some moved elements, a disabled module and a custom font, upgrades safely. Saved positions stay put, turned-off modules stay off, and migrations run once (`Core/Store.lua`).
4. **Budgets:** `test-perf-path-budgets` (reload and resize) and `test-perf-resize` under PUC Lua 5.1.
5. **Gate:** `bash scripts/gate.sh lint` and `python`. The Mac staging run is separate.
6. **Notes:** the v0.2.7 release-notes draft PR (when it exists) matches what merged.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/readiness.md`, with a clear verdict: **GO**, or **NO-GO with the exact blockers**, plus a list of things to recheck after the last two PRs. Change no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
