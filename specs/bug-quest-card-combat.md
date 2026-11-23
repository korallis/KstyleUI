# Task: blank quest card in combat (Medallions, guide shown) and the RestedXP Items box offset

**Goal**: find and fix why the quest card goes blank in combat when the RestedXP guide is shown in the Medallions HUD style, and fix the RestedXP Items box sitting a few pixels low.

**Target**: KstyleUI on `origin/staging`. Relevant code: `KstyleUI_Skins/Quests/Card.lua`, `KstyleUI_Skins/Quests/Quests.lua`, `KstyleUI_Skins/Addons/RestedXP/Rail.lua` (and its siblings), `Core/Layout/Calm.lua`, `Core/Setup/Layouts.lua`; `docs/FOREVER_DYNAMIC_SITES.md` and `docs/RELEASE_NOTES.md` describe the v0.2.2 quest-card diagnostics (zero-row snapshots in the devlog, `/kstyle test`). The owner plays an undead male warlock with an imp on 5120x1440 and 3456x2234.

**What is known**: the bug was reported on v0.2.1/v0.2.2 and never reproduced. The owner's game on Beast still runs v0.2.1 (installed `AddOns/KstyleUI/KstyleUI.toc` says `v0.2.1`), so no v0.2.2 snapshots exist. Saved data (read-only; copy it, never edit the game folder): `C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account\417741271#1\SavedVariables\KstyleUI.lua` (devlog, last session 2026-11-16 09:56 UTC, many "restedXP rail: the guide's steps reach 141 units under its part of the story rail" lines) and `!BugGrabber.lua` (only 2026-11-12 errors; one RXPGuides `GuideWindow.lua:387` nil arithmetic in `SetStepFrameAnchor`). Combat on Forever means combat lockdown and secret values (see AGENTS.md "Forever API": check `issecretvalue` before comparisons; restricted regions cannot be measured; never read state back from engine aura buttons).

**Change**:
1. Reproduce in the regression harness: boot the Skins/Quests stub environment with RestedXP's guide shown, Medallions style, enter combat (`PLAYER_REGEN_DISABLED`, `InCombatLockdown()` true, secret values where the client returns them), drive quest/guide updates during combat, and assert the card keeps its rows. Look for: layout passes skipped or aborted in combat that leave the card at zero rows; measurements of restricted regions; comparisons on secret values that throw; a hide/show on the guide frame (the RXPGuides `SetStepFrameAnchor` nil) that empties the rows; the "141 units under" rail overflow path. Write the failing test first (red), then fix the root cause (green). If you cannot reproduce it, harden every combat path you find with a test each, and improve the diagnostics so the next session captures the cause (what the devlog records on a zero-row card), and say plainly that the root cause is unconfirmed.
2. RestedXP Items box a few pixels low: render the RestedXP scene (see `docs/feature-map.md` and `verify/SKILL.md`), measure the offset against its neighbours, fix with a test.
3. Add a CHANGELOG `Fixed:` line under the unreleased section if the file has one; otherwise put it in the PR body.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**:
- AGENTS.md rules apply (CRLF/ASCII addon files via `python3 Tools/dev/crlf.py`, one comment per file, Forever API grep naming the proving file, conventions the tests enforce, `K.Widgets.FontString`, `K.Widgets.Cover`). Grep the Forever UI source before using any API; `~/.capy/work/wow-ui-source-70862` may not exist on this Windows machine, so clone `https://github.com/Gethe/wow-ui-source` branch `forever` (commit `9dc84f0`) into `C:\Users\leeba\.cache\wow-ui-source` if needed.
- Do not touch `KstyleUI_UnitFrames/`, `KstyleUI_ActionBars/`, `Core/Widgets/` or Medallions slab/hub code (another PR, #410, is changing them).
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Run Lua tests directly with `lua5.1 Tools/regression/test-<name>.lua`.
- You may push your branch and open a **draft** PR against `staging`: title `fix(skins): <summary>`, body with `## Summary`, `## Changelog` (`Fixed: ...`), `## In-game checks` (the steps the owner runs, warlock in combat with the guide shown), `## Decisions for the Captain`. Do not merge it.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Layout/Calm.lua`, `Core/Setup/Layouts.lua` (no new top-level locals), `Tools/regression/**` (tests and stubs for this bug only), `Tools/render/scenes/**`, `CHANGELOG.md`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups; Windows bar is `gate.sh lint` exit 0 plus the touched and new test files run with `lua5.1`; the draft PR's Mac CI proves the full suite.

**Evidence of done**: the new test failing at `origin/staging` and passing at your head (paste both); before/after renders of the quest card and the RestedXP Items box (paths under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\quest-card\`); the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output, evidence, and whether the root cause is confirmed.
