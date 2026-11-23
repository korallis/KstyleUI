# Task: Options windows: slider labels overlap descriptions, clipped value, Medallions preview truncation

**Goal**: the settings windows render cleanly in every HUD style: no text on top of other text, nothing cut off.

**Target**: KstyleUI on `origin/staging`, module `KstyleUI_Options/` (and the unit-frame preview it hosts). Evidence from a verifier of PR #417: `C:\Users\leeba\.cache\kstyleui-verify\verify-417-4c011921\report.md` (Attention 4 and 5) with crops `crop_opt_search.png`, `crop_opt_panel.png`, `crop_opt_search_base.png` in the same folder.

**Defects**:
1. In the three small windows of the `gallery_options` scene, the slider minimum and maximum labels (`-1985`/`1985`, `0.50`/`1.00`, `0.75`/`1.50`) are drawn on top of the slider's description text.
2. A `30` is cut off at the bottom of the search window.
3. `RENDER_HUD_STYLE=Medallions bash Tools/render/shoot.sh gallery_options --strict` exits 3: `guard: ellipsis: Frost Howler (needs 60.2 units, has 57.5)`; the preview draws "Frost Howler" much smaller than "Beast". Find whether the addon or the scene's 0.65 window scale is at fault and fix the right one.
4. At Medallions 5120x1440 the preview's portrait ring is cut by the preview card's right edge.

**Change**: fix each in the addon's layout (or the scene, for a scene-only fault), and make the render guard catch overlap of the kind in 1 if it can be done in a few lines in `Tools/render/guard.lua`; otherwise add a regression test in `Tools/regression/` that asserts the slider labels sit clear of the description. Every fix gets a test that fails on staging.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python3 Tools/dev/crlf.py`, one comment per file, `K.Widgets.FontString`, Forever API grep, locale strings via `Tools/locale/strings.py sync` if any string changes). Do not touch `KstyleUI_UnitFrames/`, `KstyleUI_ActionBars/`, `KstyleUI_GroupFrames/`, `Core/Widgets/Medallion.lua`, `Core/Widgets/UnitBar.lua`, `Core/Setup/` (PR #410) or `Tools/render/` other than `guard.lua` and `scenes/gallery_options*` (PR #417). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. You may push your branch and open a **draft** PR against `staging`: title `fix(options): <summary>`, body with `## Summary`, `## Changelog` (`Fixed: ...`), `## In-game checks`. Do not merge it.

**Files it may edit**: `KstyleUI_Options/**`, `Core/Locales/**` (only via strings.py), `Tools/render/guard.lua`, `Tools/render/scenes/gallery_options*`, `Tools/regression/**` (tests for these defects).

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and the shared C:\dev\null are known). Windows bar: `gate.sh lint` exit 0 plus touched and new tests under `lua5.1`; the draft PR's Mac CI proves the rest.

**Evidence of done**: before/after crops of each defect at Frames and Medallions, 1920x1080 and 5120x1440 (under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\options\`), opened and described; `gallery_options --strict` exit 0 in all three HUD styles; new tests red on staging and green after; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
