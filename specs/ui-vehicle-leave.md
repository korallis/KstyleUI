# Task: vehicle leave button out of the Medallions hub gap

**Goal**: in every HUD style, the vehicle leave button sits in a clear, reachable spot that never covers the hub or the action buttons.

**Target**: KstyleUI on `origin/staging` (it has #410: one row of action buttons per side, buttons above the hub). `KstyleUI_ActionBars/Vehicle.lua` anchors the leave button right of bar 1, which under Medallions puts it in the gap over the crest hub (finding from a v0.2.1 acceptance pass). Layout rules live in `Core/Setup/Layouts.lua` and the Medallions slab/hub code in `KstyleUI_ActionBars/Slab.lua`.

**Change**: place the leave button for Medallions where the KSTY-110 design leaves room (for example beside the pet/stance slab or at the slab's outer end; decide from the layout code and the renders, and record the choice under Decisions in the PR); keep Frames and Orbs where they are unless they also collide. Add a regression test that boots ActionBars in a vehicle (`UnitHasVehicleUI`/`CanExitVehicle` true, per the Forever UI source) in all three styles at 5120x1440, 3456x2234 and 1920x1080 and asserts the button sits clear of the hub, the action buttons, the pet/stance slabs and the unit cluster. Respect combat lockdown (the button is protected: move it only out of combat or through the secure anchor path; use `K.Widgets.Cover` for any overlay).

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python3 Tools/dev/crlf.py`, one comment per file, Forever API grep naming the proving file, no top-level locals added to `Core/Setup/Layouts.lua`). One row of action buttons on every screen; action buttons always above the hub. Do not touch `Core/Widgets/Medallion.lua` (the rune rim task runs in parallel). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. You may push your branch and open a **draft** PR against `staging`: title `fix(actionbars): keep the vehicle leave button out of the hub gap`, body with `## Summary`, `## Changelog` (`Fixed: ...`), `## In-game checks` (owner: board a vehicle as the warlock in each style), `## Decisions`. Do not merge it.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Setup/Layouts.lua`, `Tools/regression/**` (tests for this), `Tools/render/scenes/**` (a vehicle scene if needed), `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and four known files remain for PR 7). Windows bar: `gate.sh lint` exit 0 plus touched and new tests under `lua5.1`; the draft PR's Mac CI proves the rest.

**Evidence of done**: the new test red on staging and green after; renders of the warlock in a vehicle in all three styles at the three screens (under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\vehicle\`), opened and described; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
