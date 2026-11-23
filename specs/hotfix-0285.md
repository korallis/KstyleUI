# Task: build hotfix v0.2.8.5 from the released v0.2.8.4

Players run tag `v0.2.8.4` (main). Port this bug fix, merged on `staging`, onto a branch `hotfix/v0.2.8.5` created from tag `v0.2.8.4`. Staging has many features the release lacks (e.g. Meters' second damage window, parity rounds), so **port the fix, not the squash commit**: cherry-pick when it applies cleanly, otherwise re-apply the smallest equivalent change to the v0.2.8.4 code, with its regression test adapted to v0.2.8.4.

1. `110adc27e` (#651) — with the target aura filter "Debuffs and buffs", the target's aura rows clear the HUD (Orbs timers move to the icon corners, Medallions shows one row of each kind); the rule applies to the target frame only; the Options preview shows both rows; and the Nameplates UNIT_FLAGS path skips re-hiding a hidden glow (perf). Port it onto v0.2.8.4: v0.2.8.4 already has #637's timer lane.

Then add a branded `## v0.2.8.5` CHANGELOG section and a `docs/RELEASE_NOTES.md` section in the exact style of v0.2.8.4 (short "A small fix release." intro, 3-4 highlights, `### Fixed` list, player words). Do not edit `KstyleUI_Options/Notes.lua` on the hotfix branch unless v0.2.8.4 has that file and its test (it does not; staging does).

**Checks on the branch**: `bash scripts/gate.sh lint`, `python`, and under PUC Lua 5.1 every test the ported files load (`run-all.sh --affected v0.2.8.4` may be used; explicit file lists are fine), plus `test-taint-scan`, `test-perf-path-budgets`. Renders at all four sizes for each fix (before/after on v0.2.8.4), `--strict`, over a game backdrop; default looks unchanged except where each fix intends. Push `hotfix/v0.2.8.5` and run `gh workflow run checks.yml --ref hotfix/v0.2.8.5` (includes the Mac shards); report the run id when green.

**Do not** tag, push to main, merge or post anything. Open no PR (the coordinator fast-forwards main and tags).

**Also**: open a PR to `staging` that adds the same v0.2.8.5 CHANGELOG and RELEASE_NOTES sections **and** the v0.2.8.5 entry in `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste), translated in `Tools/locale/<code>.json` with `strings.py sync`. Title `docs(release): v0.2.8.5 notes`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the hotfix branch SHA, the checks run id, and the notes PR number.
