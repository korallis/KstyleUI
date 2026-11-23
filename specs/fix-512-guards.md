# Task: make draft PR #512 (data bar top bar) pass the #504 overlap guards

**Goal**: #512 (branch `korallis/databar-top-bar-zones`, head 93e05dd5) fails the full-HUD guards that #504 added. The data bar part 5 worker reproduced it on a clean checkout of 93e05dd5; logs are `C:/Users/leeba/.cache/kstyleui-evidence/databar-5/base-reach.log` and `base-property.log`. Work on #512's branch, and rebase onto the latest `origin/staging` first.

1. `test-hud-reach-frames-dps-screens-04-06` rejects the top bar's chrome bleeding off the screen edges. **Keep it simple and consistent:** draw the chrome inside the screen, with no bleed, and use the same 0-margin full-width rect the guard expects. Don't add a guard exemption.
2. In the same test, `cooldowns.utility` overlaps `skins.quests` once the top inset applies. Fix it with the least default move, or by applying the inset consistently to both, and never move a saved position.
3. `test-property-layout` seed 20261114 case 1 (5460x1571, Healer, Orbs, Spread, 16:9): `unitframes.focus` overlaps `groupframes.raid`. Find whether #512's inset causes it (compare with staging). Fix the default with the least change.

**Tests**: the whole #504 matrix, the reach tests, `test-property-layout` and `test-perf-path-budgets` pass under PUC Lua 5.1. Renders of the top bar at the four sizes in Frames and Orbs.

**Constraints**: minimal code; CRLF/ASCII. Keep migration 41 unless staging already has 41 (then take the next). Force-push with lease, and the PR stays a draft. Do not merge. Two PRs (#530 and #531) are stacked on this branch, so push as soon as you're done.

**Gate**: lint, python and those tests. Send worker_done once local proof is done.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
