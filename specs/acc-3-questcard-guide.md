# Task: v0.2.3 acceptance fix: quest card shows objectives beside the RestedXP guide

**Goal**: with the RestedXP guide open in Medallions, the quest card shows at least the first quest's title and its objective progress on every screen.

**Target**: KstyleUI, branch from the latest `origin/staging`. Acceptance report: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023\REPORT.md`, finding 3, with `sheets/questcard-guide-medallions.png`. At 3456x2234 and 1920x1080 the card shows one title and "7 more, scroll down"; the objective line ("Putrid Claw 0/7") is cut, so no progress shows at any scroll position; 5120x1440 is fine. Code: `Core/Setup/Layouts.lua:628-631` (the quests get a 98-unit slot while the guide is shown), `KstyleUI_Skins/Quests/Card.lua:324` and `:529` (lines past the limit are dropped).

**Change**: guarantee the card's minimum useful height: a quest's title and at least its first objective line always fit together (a row is never split so that the objective is dropped while its title shows). Either give the quest slot enough height beside the guide (take it from the guide or the rail's spare space; keep the guide's own steps readable) or make the card show one complete quest (title plus objectives) per page with the scroll hint. Pick the one that reads best at 3456x2234 and 1920x1080, and record the choice under Decisions. Tests at the three screens with the guide shown: the first quest's objective line is visible; scrolling shows each quest's objectives.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files, one comment per file, no new top-level locals in `Core/Setup/Layouts.lua`, `K.Widgets.FontString`, combat-safe layout: keep #418's per-quest retention behaviour). Do not edit `KstyleUI_UnitFrames/` or `KstyleUI_ActionBars/` (parallel tasks). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. You may push your branch and open a **draft** PR against `staging`: title `fix(skins): quest card keeps objectives beside the RestedXP guide`, body with `## Summary`, `## Changelog` (`Fixed: ...`), `## In-game checks`, `## Decisions`. Do not merge it.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Setup/Layouts.lua`, `Tools/regression/**` (tests for this), `Tools/render/scenes/**` (quest card scenes), `docs/feature-map.md`, `docs/statecharts/**` if a chart covers this layout.

**Gate**: `bash scripts/gate.sh` (lint exit 0; touched and new tests under `lua5.1`; the draft PR's Mac CI proves the rest).

**Evidence of done**: before/after renders of the quest card beside the guide in Medallions at the three screens (and Frames/Orbs to show nothing regressed) under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-fix-3\`, opened and described; new tests red on staging and green after; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
