# Task: v0.2.7 last gate: targeted recheck of staging f3542cbd (read-only), GO or NO-GO

**Goal**: the final recheck (`C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md`) was NO-GO on B3 (partly fixed), B5 and B6. Their fixes have merged: #538 (B3b, re-running setup with Right rail), #539 (B5, the clock clears the gem at 14 units) and #540 (B6, which turned out to be a render-fixture artefact; the fixture is fixed and a live test added). Confirm on `origin/staging` f3542cbd and give a final verdict.

**Check** (renders in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/final/`, never committed):
1. Reproduce each of B3b, B5 and B6 with the recheck's own scripts and renders; each must now pass. For B6, confirm in the live Skins and Minimap environment that the Crest ring plaque clears the RestedXP header, and say whether the fixture now matches the live game.
2. Re-run the full `hud_reference --strict` matrix the recheck used: 45 renders (3 styles x DPS/Tank/Healer x 1080/1440/5120 Centred and Spread/4K), plus the Frames and Orbs top bar at 14 units and the Medallions dock. Every one must pass, and look at the top-bar centres and the Medallions centres.
3. The Frames Auto size still equals v0.2.6 at 2560x1440 and 5120x1440. `test-perf-path-budgets` passes. Gate lint and python pass.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/final.md`, giving **GO**, or **NO-GO with the exact blockers**. Change no code. Be fast: this is the last gate.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
