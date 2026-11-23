# Task: tooltips follow the mouse out of combat and sit at their anchor in combat

**Goal**: the owner: "can the tooltip also be under the mouse, but not in combat?" Add a tooltip position choice that puts the tooltip at the cursor out of combat and at the placed tooltip anchor in combat, and make it the default.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_Tooltips/Anchor.lua:107-108` (today: `Settings.Get("anchor") == "cursor"` uses `ANCHOR_CURSOR_RIGHT` with `cursorX`/`cursorY`, otherwise the placed anchor element), `KstyleUI_Tooltips/Settings.lua` (the anchor choice list around :111 with "Mouse cursor", the cursor offset sliders shown only for cursor via `Cursor(settings)` at :68).

**Change**:
1. Add a third anchor choice, "Mouse cursor out of combat": at the cursor (same offsets) while the player is not in combat, at the placed anchor element in combat. Decide by combat state when the tooltip is shown (`InCombatLockdown()` or the addon's own combat state, whichever `Core/Combat` uses; grep the Forever UI source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`, for the anchor types used and name the file). A tooltip already open when combat starts may keep its position until it next shows.
2. Make it the default for new profiles and for players who never changed the anchor setting; an explicitly saved "Anchor" or "Mouse cursor" choice is kept. Show the cursor offset sliders for both cursor choices.
3. Strings through `python Tools/locale/strings.py sync` with real translations; update the Tooltips README and `docs/feature-map.md`.
4. Tests: out of combat the owner is the cursor anchor with the offsets; in combat it is the anchor element; saved explicit choices are preserved; the default for a fresh profile is the new choice.

**Constraints**: AGENTS.md rules (CRLF/ASCII, one comment per file, Forever API grep, secret values, one event handler per owner). Another task will later change tooltip text sizes in `KstyleUI_Tooltips/Settings.lua`; keep to the anchor setting and rebase before the PR. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `feat(tooltips): follow the mouse out of combat`, `## Summary`, `## Changelog` (`Added: Tooltips can follow the mouse out of combat and sit at their usual place in combat; this is the new default.`), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_Tooltips/**`, `Core/Locales/**` and `Tools/locale/*.json` via strings.py, `Tools/regression/**`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: the behaviour tests red before (no such choice) and green after; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and Gate output.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
