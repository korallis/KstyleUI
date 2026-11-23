# Task: v0.2.3 acceptance fix: the crest fills the Medallions hub

**Goal**: the race-and-class crest in the Medallions hub reads as the centrepiece the mocks show, not a small dim emblem in an empty socket.

**Target**: KstyleUI, branch from the latest `origin/staging`. Acceptance report: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023\REPORT.md`, finding 2, with `crops/hub-5120-mock110_staging_ksty88.png` (KSTY-110 mock, staging, KSTY-88 close-up) and `sheets/sbs-medallions-*.png`. The crest covers about 0.55 of the ring's width; the KSTY-110 mock fills the ring's opening and the KSTY-88 close-up about 0.85; the wide black band reads as an empty socket. Code: `KstyleUI_ActionBars/Slab.lua:14` (`RING, CREST, SOCKET = 150, 108, 118`), `:20` (`CREST_REST = 0.9`), `:411-413`; the bake fits the crest to 900/1024 of its canvas (`docs/medallions.md:61`, `Tools/medallions/`). KSTY-88 close-ups: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\KSTY-88\` (e.g. `02-crest-closeup-undead-warlock-*`).

**Change**: size the crest (and socket) so it fills the ring's opening like the KSTY-110 mock, and restore its brightness at rest (check `CREST_REST` and any dimming in combat/rest states against the mock and the KSTY-88 close-ups). Keep the hub ring size, the one row of action buttons on every screen, and action buttons above the hub. If the baked crest art has too much empty margin, re-bake with the repo's tool (original art only) rather than scaling a blurry texture; keep it crisp at 5120x1440. Add a test that pins the crest-to-ring ratio and the rest alpha.

**Playbook**: none.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python3 Tools/dev/crlf.py`, one comment per file); all art original; no textures around bars. Do not edit `KstyleUI_UnitFrames/`, `KstyleUI_Skins/` or `Core/Setup/Layouts.lua` (parallel tasks). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering; the handoff folder and atlas cache are on this machine. You may push your branch and open a **draft** PR against `staging`: title `fix(medallions): the crest fills the hub`, body with `## Summary`, `## Changelog` (`Changed: ...`), `## In-game checks`, `## Decisions`. Do not merge it.

**Files it may edit**: `KstyleUI_ActionBars/Slab.lua`, `KstyleUI_ActionBars/README.md`, `Tools/medallions/**`, `Media/Textures/Medallions/**` (re-baked crests only), `Media/PROVENANCE.md`, `docs/medallions.md`, `Tools/regression/**` (tests for this), `Tools/tests/test_medallions*.py`.

**Gate**: `bash scripts/gate.sh` (lint and python exit 0; touched tests under `lua5.1`; the draft PR's Mac CI proves the rest).

**Evidence of done**: side-by-side sheets (KSTY-110 mock, staging, after, KSTY-88) of the hub for the undead warlock and two other race/class crests at 5120x1440, 3456x2234 (game fit) and 1920x1080, under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-fix-2\`, opened and described; `--strict` exit 0; Frames/Orbs pixel diff empty; the new test red on staging and green after; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
