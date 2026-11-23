# Task: EllesmereUI parity, the last single rows in Options, Bags and Auras

**The owner's decision**: v0.2.9 waits until every "Missing, fits" parity row is built. These modules each have one or two rows left on `origin/staging`; build them in one PR. The rules in `C:/Projects/KstyleUI/specs/parity-frames.md` and the module template `C:/Projects/KstyleUI/specs/parity-module.md` apply (every new option off or at today's value, live previews, Forever API proof at 9dc84f0, secret-safe, combat-safe, one event owner, no hot-path cost while off, minimal code, consistent look).

- `KstyleUI_Options/README.md`: the two "Missing, fits" rows (chat input font mirror; per-spec cooldown rules in profile sharing) and the WagoUI adapter note from round 2 (build the adapter if WagoUI's API is documented, else narrow the claim).
- `KstyleUI_Bags/README.md`: Quick actions (secure Disenchant/Pick Lock/Prospect/Mill button). Prove the spell IDs on Forever at 9dc84f0 and in the client's DB2 data under `~/.cache` if present; if they cannot be proven, mark the row Not possible with the reason.
- `KstyleUI_Auras/README.md`: Aura reminders (the row Options round 2 added): a missing-buff reminder for the player's own class buffs, in the shared card look, off by default.

**Evidence** (in `C:/Users/leeba/.cache/kstyleui-evidence/parity-odds/`): 0-pixel default diffs at 1920x1080 and 5120x1440; enabled renders at all four sizes `--strict` over a game backdrop; module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; lint, python; hosted CI green. One PR to `staging`, `feat(options): EllesmereUI parity, last rows` (pr-rules refuses comma scopes), with `## Changelog` `Added:` lines and `## In-game checks`. Update each README's counts. Do not merge.

**Files it may edit**: `KstyleUI_Options/**`, `KstyleUI_Bags/**`, `KstyleUI_Auras/**`, `Core/Profiles.lua` (profile sharing only), `Core/Locales/*`, `Tools/locale/*`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
