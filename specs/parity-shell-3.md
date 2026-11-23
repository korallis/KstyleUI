# Task: EllesmereUI parity follow-up: minimap, data texts, chat, bags, tooltips and QoL, batch 3 (the next most player-visible rows)

The first parity batch for these modules is merged. Each module README now has a parity table whose "Missing, fits" rows and follow-up batches (listed in each README) are the backlog. Read those README sections on `origin/staging` and the original spec `C:/Projects/KstyleUI/specs/parity-shell.md`. Its rules all apply: reuse the shared builders, keep today's look unless an option is a clear improvement (then default it ON and say why), no per-frame work, secure changes queued in combat, every API proven at `9dc84f0`, and one consistent style.

**Build batch 3**: skip rows already built in batches 1 and 2 (marked Present in the README tables); the most player-visible "Missing, fits" rows, up to about 600 lines of Lua. Mark the built rows Present in the README tables. Rows only; no new modules.

**Reload budget**: about 12.4M of the 13.0M ceiling; new options must stay lazy and add **no** reload cost; prove it with `test-perf-path-budgets`. If a row can't be built without reload cost, skip it and say why.

**Tests**: each new option writes and applies, its default is unchanged, a v0.2.8 profile loads, and the perf budget passes.

**Renders**: base-against-PR **pixel diffs** of the affected default scenes at 1920x1080 and 5120x1440, which must be zero for defaults, plus the Options pages. Use `--strict` and real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/parity-shell-3/`.

**PR**: open a PR (not a draft) against `staging` titled `feat(options): more minimap, data text, chat, bag, tooltip and QoL options`. Include `## Changelog` (`Added:` lines in player words), `## Options`, `## In-game checks` and `## Forever API`. Do not merge.

**Files it may edit**: the modules' folders (for core: `Core/Layout/**`, `Core/Profiles.lua`, `Core/Appearance.lua`, `Core/Scale.lua`), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Constraints**: CRLF/ASCII; locales synced. Beast speed rule. Other parity and perf PRs run in parallel; rebase before opening.

**Gate**: lint, python, the modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, the rows built and the rows left.
