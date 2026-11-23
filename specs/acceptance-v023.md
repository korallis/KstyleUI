# Task: acceptance of staging for v0.2.3

**Goal**: an independent judgement that staging, as it stands, is ready to ship as v0.2.3: it matches the design, breaks none of the product rules, and has no defect a player would hit.

**Target**: KstyleUI, the latest `origin/staging` (check out the exact SHA and name it in your report). Design references: the KSTY-110 mock (linked in merged PR #410's Pictures section; `gh pr view 410 --json body`), the KSTY-88 crest close-ups in `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\KSTY-88\`, `docs/medallions.md`, `docs/feature-map.md`. Product rules: one row of action buttons on every screen; action buttons always above the hub; no textures around bars; all art original. The owner plays an undead male warlock with an imp on 5120x1440 and 3456x2234: judge that case first.

**Change**: no code changes. Judge and report.
1. Render with `--strict` (see `verify/SKILL.md` and `docs/feature-map.md`) the warlock in Frames, Orbs and Medallions, layouts DPS/Tank/Healer, at 5120x1440, 3456x2234 (game fit) and 1920x1080; plus the Options gallery, quest card with the RestedXP guide, a vehicle, party and nameplates. Open every picture.
2. Put Medallions side by side with the KSTY-110 mock at the same scale and crop, at the three screens. A known lesson: an earlier acceptance judged pieces one by one and missed that the composed slab was wrong; judge the composed HUD.
3. For each finding: severity (blocker / should-fix / note), the screen and style, a crop path, and the file most likely responsible.
4. Also add the missing tests a verifier flagged for the live aura style switch: Orbs to Medallions, Frames to and from Orbs, and a switch during real combat lockdown, in `Tools/regression/test-unitframes-aura-style-switch.lua` (the only file you may edit); each must pass on staging (they pin current behaviour).

**Playbook**: question / read-only -> cite file:line; change no code (except the one test file above).

**Constraints**: Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Renders and crops go under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023\`. You may push a branch with the test file and open a **draft** PR against `staging` (title `test(unitframes): pin the live aura style switch for every style pair`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tests"), `## In-game checks` ("None")). Do not merge.

**Files it may edit**: `Tools/regression/test-unitframes-aura-style-switch.lua`.

**Gate**: `gate.sh lint` exit 0 and the edited test under `lua5.1`.

**Evidence of done**: the report at `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023\REPORT.md` with the verdict (SHIP / FIX FIRST), the findings table, and the side-by-side sheets; the test PR URL and its green `checks` run.

**Before worker_done**: Conventional Commits subjects. Report the staging SHA judged, the verdict, the blocker list, the PR URL and run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
