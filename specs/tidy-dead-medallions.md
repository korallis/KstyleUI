# Task: remove unused Medallions art and code (medSteelCard, Steel material, Effects.TargetGlow and its bracket-glow texture)

**Goal**: delete dead code and assets so the addon and the release zip carry only what is used.

**Target**: KstyleUI on `origin/staging`. Known references: `Core/EffectBursts.lua`, `Core/Tokens.lua`, `Core/Widgets/Base.lua`, `Tools/media/make_media.py`, `Tools/media/medallions_kit.py`, and the texture files under `Media/` they name, plus any test under `Tools/regression/` that pins them.

**Change**: prove each item is unused (grep every reference in addon code, TOC/XML, tests, render scenes and tools; confirm no runtime path reaches it, e.g. by name lookup through a table or string concatenation), then delete: the `medSteelCard` texture and its registration; the `Steel` material; `Effects.TargetGlow` and its bracket-glow texture. Remove their entries from the media generators and from any texture registry (texel tables) and update tests that only pinned their existence. If anything turns out to be used, keep it and say where.

**Playbook**: refactor -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\refactoring.md`, steps 1, 4, 5, 6, 8 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules apply (CRLF/ASCII addon files via `python3 Tools/dev/crlf.py`, one comment per file). `Core/Tokens.lua` is a sensitive path: change only the lines that define the removed items and say why in the PR body. Do not touch `KstyleUI_UnitFrames/`, `KstyleUI_ActionBars/`, `KstyleUI_GroupFrames/`, `Core/Widgets/Medallion.lua`, `Core/Widgets/UnitBar.lua` or `Core/Setup/` (PR #410 is changing them). Renders of the owner's warlock (Medallions, 5120x1440 and 1920x1080, `--strict`) must be pixel-identical before and after. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. You may push your branch and open a **draft** PR against `staging`: title `refactor(medallions): remove unused steel card, steel material and target glow`, body with `## Summary`, `## Changelog` (`Changed: smaller download: unused Medallions art removed`), `## In-game checks`. Do not merge it.

**Files it may edit**: `Core/EffectBursts.lua`, `Core/Tokens.lua` (the removed definitions only), `Core/Widgets/Base.lua`, `Tools/media/**`, `Media/**` (deleting the unused files), `Tools/regression/**` (tests that pinned the removed items), `docs/**`.

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively on Windows now; failures from Lua shell calls fixed by #413 and Windows wall-clock overruns are known; touched tests must pass with `lua5.1`). Windows bar: `gate.sh lint` exit 0 plus touched tests; the draft PR's Mac CI proves the rest.

**Evidence of done**: the reference greps before and after; the before/after pixel diff of the warlock renders (no bounding box); the zip size before and after (`Tools/hooks/check-package.sh` on a local package, or the size of the deleted files); the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
