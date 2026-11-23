# Task: rebase draft PR #511 (Medallions extra-bar presets) onto staging and resolve conflicts

**Goal**: PR #511 (branch `korallis/medallions-extra-bar-presets`, head a390fc4b) passed review, but it conflicts with the latest `origin/staging`. #504 (nothing overlaps or leaves the screen) has since merged. It moved the Medallions pet and stance bars and changed the display clamp and the Layouts footprints. Rebase #511 onto the latest staging, resolve the conflicts, and keep both PRs' intent:
- Presets Off is identical to staging.
- C and D still match their mockups and keep clear of #504's new pet and stance places.
- #504's 378-case overlap matrix and #511's 48 preset cases both pass.

Also apply the review's small cut, if it is behaviour-identical: `Slab.lua:849` becomes a plain `for _, key in ipairs(SIDE_BARS)`, as long as the reload budget allows it.

**Tests**: `test-layout-extra-presets`, `test-actionbars-extra-presets`, `test-layout-medallions`, `test-layouts-locals`, #504's reach and overlap tests, and `test-perf-path-budgets`, all under PUC Lua 5.1. Strict renders of Off, C and D at 1920x1080 and 5120x1440. Off must match staging pixel for pixel.

**Constraints**: minimal change; CRLF/ASCII. Force-push with lease to the same branch, and the PR stays a draft. Do not merge.

**Gate**: lint, python and those tests. Send worker_done once local proof is done.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the new SHA and run id.
