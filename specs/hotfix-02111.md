# Task: build hotfix v0.2.11.1 from the released v0.2.11

Players run tag `v0.2.11` (main). Port this bug fix, merged on `staging`, onto a branch `hotfix/v0.2.11.1` created from tag `v0.2.11`. Staging has later features (crowns, cast bars on frames), so **port the fix, not the squash commit**: cherry-pick when it applies cleanly, otherwise re-apply the smallest equivalent change to the v0.2.11 code, with its regression test adapted.

1. `afbdbc95c` (#692) — with the Cooldown Manager switched off (CVar `cooldownViewerEnabled`), KstyleUI no longer draws its own essential/utility cooldown rows (they showed above the crest); the switch applies live without a reload; no stale Layout movers; the one-time hint stays quiet on a deliberate switch-off.

Then add a branded `## v0.2.11.1` CHANGELOG section and a `docs/RELEASE_NOTES.md` section in the style of earlier hotfixes (short "A small fix release." intro, highlights, `### Fixed` list, player words), and the v0.2.11.1 entry in `KstyleUI_Options/Notes.lua` (v0.2.11 has the file: run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste), translated in `Tools/locale/<code>.json` with `python3 Tools/locale/strings.py sync`, then `python3 Tools/dev/crlf.py`.

**Checks on the branch**: `bash scripts/gate.sh lint`, `python`, and under PUC Lua 5.1 every test the ported files load plus `test-taint-scan`, `test-perf-path-budgets`, `test-options-notes`, `test-options-preview-content-locales`. Push `hotfix/v0.2.11.1` and run `gh workflow run checks.yml --ref hotfix/v0.2.11.1` (includes the Mac shards); report the run id when green.

**Do not** tag, push to main, merge or post anything. Open no PR for the hotfix branch (the coordinator fast-forwards main and tags).

**Also**: open a PR to `staging` that adds the same v0.2.11.1 CHANGELOG, RELEASE_NOTES and Notes.lua entry (with translations). Title `docs(release): v0.2.11.1 notes`, label `no changelog`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the hotfix branch SHA, the checks run id, and the notes PR number.
