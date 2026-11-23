# Task: build hotfix v0.2.8.4 from the released v0.2.8.3

Players run tag `v0.2.8.3` (main). Port these four bug fixes, merged on `staging`, onto a branch `hotfix/v0.2.8.4` created from tag `v0.2.8.3`. Staging has many features the release lacks (e.g. Meters' second damage window, parity rounds), so **port the fix, not the squash commit**: cherry-pick when it applies cleanly, otherwise re-apply the smallest equivalent change to the v0.2.8.3 code, with its regression test adapted to v0.2.8.3.

1. `5a37eded0` (#634) — the docked threat card in Meters "Both" overlapped the Frames stance bar and the Medallions bar 2 / XP strip at 1920x1080, 2560x1440 and 3840x2160. On v0.2.8.3 there is no second window: dock the threat card at the HUD-clear width (180 units, as on staging) and prove it clears every HUD element at all four sizes, all three styles and layouts. Include the README note about long names.
2. The `KstyleUI_UnitFrames/Preview.lua` part of `8c2363a4d` (#635) — the Options unit-frame preview keeps the cast bar's HUD share in a narrow pane. Skip the harness (`Tools/render/**`, stubs) changes unless the regression needs them.
3. `f88d51afe` (#637) — target debuff timers placed below their icons no longer draw over the buff row (groupLineSpacing timer lane). Bring the render-guard part only if needed for its test.
4. `1361d42ae` (#641) — the Minimap preview in Options re-lays out on rescale (no path-dependent sizes).

Then add a branded `## v0.2.8.4` CHANGELOG section and a `docs/RELEASE_NOTES.md` section in the exact style of v0.2.8.3 (short "A small fix release." intro, 3-4 highlights, `### Fixed` list, player words). Do not edit `KstyleUI_Options/Notes.lua` on the hotfix branch unless v0.2.8.3 has that file and its test (it does not; staging does).

**Checks on the branch**: `bash scripts/gate.sh lint`, `python`, and under PUC Lua 5.1 every test the ported files load (`run-all.sh --affected v0.2.8.3` may be used; explicit file lists are fine), plus `test-taint-scan`, `test-perf-path-budgets`. Renders at all four sizes for each fix (before/after on v0.2.8.3), `--strict`, over a game backdrop; default looks unchanged except where each fix intends. Push `hotfix/v0.2.8.4` and run `gh workflow run checks.yml --ref hotfix/v0.2.8.4` (includes the Mac shards); report the run id when green.

**Do not** tag, push to main, merge or post anything. Open no PR (the coordinator fast-forwards main and tags).

**Also**: open a PR to `staging` that adds the same v0.2.8.4 CHANGELOG and RELEASE_NOTES sections **and** the v0.2.8.4 entry in `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste), translated in `Tools/locale/<code>.json` with `strings.py sync`. Title `docs(release): v0.2.8.4 notes`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the hotfix branch SHA, the checks run id, and the notes PR number.
