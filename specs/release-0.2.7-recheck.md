# Task: v0.2.7 final readiness recheck (read-only): GO or NO-GO

**Goal**: the first readiness review (`C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/readiness.md`) said NO-GO, with blockers B1–B3 and the notes issue B4, plus a recheck list for the Medallions layout PR. These have since merged: #533 (Medallions centred cooldowns and aura rows), #535 (B1, meter width), #536 (B2, the quest card) and #537 (B3, the 14-unit data bar and Right rail). Recheck the latest `origin/staging` as an independent reviewer, and give a final **GO** or **NO-GO**.

**Check** (renders in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck/`, never committed):
1. Each of B1–B3 is fixed, using the same renders and commands the first review used.
2. The recheck list from the first review, for #533 and #530.
3. A fresh `hud_reference --strict` matrix: Medallions, Frames and Orbs, for DPS, Tank and Healer, at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160. Look at every picture for overlaps, clipping, off-screen parts and style consistency. Pay special attention to the Medallions centre (cooldowns, cast bars, aura rows, the consumables bar, extra-bar presets C and D, the data bar dock) and to the Frames top bar at 14 units.
4. The Frames Auto size at 2560x1440 and 5120x1440 equals v0.2.6's, and top-anchored elements match v0.2.6.
5. The upgrade from a v0.2.6 profile, re-run quickly: saved positions, disabled modules, custom font, and migrations once.
6. `test-perf-path-budgets` and `test-perf-resize` under PUC Lua 5.1, plus gate lint and python.
7. **The release notes PR #534:** list exactly what must change so they claim only what shipped and include every visible change. Include B4 from the first review and the owner decisions: the 14-unit bar (no shrink), the Crest fan option, positions saved near a screen edge drawn inward, RestedXP boxes re-docking (migration 40), the dock showing the original five readouts by default, and the 250-unit meter cards. Write the exact replacement text.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md`, with **GO** or **NO-GO plus exact blockers**, and the exact release-notes edits. Change no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Be fast: this is the last gate before release.
