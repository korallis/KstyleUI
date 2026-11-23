# Task: offer to add newly learned spells to the action bars, beside the rank update

**Goal**: the owner: "the new spell rank is a massive success, but we should also enhance this so that new spells can be added automatically too, so there's an Update bars and an Add new to bars button." When the player learns a spell that is not on their bars yet, KstyleUI offers to put it in the next free slot, in the same prompt as rank updates.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_ActionBars/Ranks.lua` (today: on learning a higher rank of a spell already on the bars, asks or acts per the `ranks` setting, then puts the new rank in every slot that held a lower one with `C_Spell.PickupSpell`, `PlaceAction`, `ClearCursor`, `GetCursorInfo`; the prompt offers "Not now" and "Update bars"), `KstyleUI_ActionBars/Settings.lua:242` (the `ranks` dropdown). Grep the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`) for how the client learns spells and whether it auto-places them itself (`LEARNED_SPELL_IN_TAB`, `SPELLS_CHANGED`, `SPELL_PUSHED_TO_ACTIONBAR`, any `AutoPushSpellToActionBar` CVar, `C_SpellBook`), and name the files. If the client already pushes new spells to bar 1, KstyleUI must not fight it or place a spell twice.

**Change**:
1. Detect newly learned spells (castable actives, not passives, professions or ranks of spells already on the bars) and collect them while the player is busy; never act in combat (wait until combat ends).
2. One prompt for both: list new ranks and new spells; buttons "Not now", "Update bars" (ranks, as today) and "Add new to bars" (new spells). When only one kind is pending, show only its button. "Add new to bars" places each new spell in the next empty slot, filling bar 1 then bar 2 left to right (the slots a player sees first in each HUD style), never overwriting an occupied slot, skipping hidden bars; if no slot is free, say so.
3. A setting beside `ranks`: "New spells" with Ask (default), Always add, Never. Per the owner rule, it is on (Ask) by default.
4. Tests: a new spell triggers the prompt; Add places it in the first empty slot and nowhere else; ranks still update as before; combat defers; a full bar reports no room; passives and professions are ignored; the client's own auto-push (if it exists) is not duplicated.
5. Strings through `python Tools/locale/strings.py sync` with real translations; update `KstyleUI_ActionBars/README.md` and `docs/feature-map.md`; render the prompt in the KstyleUI style.

**Constraints**: AGENTS.md rules (CRLF/ASCII, one comment per TOC-loaded file, Forever API grep, combat lockdown: `PlaceAction` and cursor operations only out of combat; one event handler per owner). Another worker is changing `KstyleUI_ActionBars/Button.lua`, `Slab.lua` and `Settings.lua` rows for the slab: keep to `Ranks.lua` and your settings row, and rebase before the PR. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `feat(actionbars): offer to add new spells to the bars`, `## Summary`, `## Changelog` (`Added: When you learn a new spell, KstyleUI offers to add it to your action bars, beside the rank update.`), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/Ranks.lua`, `KstyleUI_ActionBars/Settings.lua` (the new row only), `KstyleUI_ActionBars/README.md`, `Core/Locales/**` and `Tools/locale/*.json` via strings.py, `Tools/regression/**`, `Tools/render/scenes/**`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: behaviour tests; a render of the combined prompt; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and Gate output.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
