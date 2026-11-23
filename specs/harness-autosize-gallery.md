# Task: render harness fixes: auto size honours the game's fit check; gallery_options and gallery_unitframes

**Goal**: make the render harness draw what the game draws, so renders can be trusted for acceptance and the README.

**Target**: KstyleUI on `origin/staging`, the render harness in `Tools/render/` (`shoot.sh`, `scenes/`, `_common.lua`, `README.md`). `docs/feature-map.md` and `verify/SKILL.md` describe how to run it on this Windows machine (Chrome shim at `C:\Users\leeba\.cache\kstyleui-verify\chrome-shim.sh`, the `C:\dev` folder).

**Change**:
1. LEE-1491: with `RENDER_SIZE=auto` the harness ignores the game's HUD fit check, so a render at 3456x2234 comes out at scale 1.0 where the game uses 0.8158. Make auto size run the same fit code the addon runs (find it under `Core/`, e.g. the setup/layout fit search; call the real Lua, do not copy the numbers), and add a test that fails today: at 3456x2234 the auto size equals the game's value (0.8158 within rounding), and at 5120x1440 and 1920x1080 it matches the addon's own fit result.
2. LEE-1542: the `gallery_options` and `gallery_unitframes` scenes are broken. Run both with `--strict`, list every failure (missing textures drawn as grey boxes, truncation, spills, errors), and fix the scene or harness code so both pass `--strict` on staging. If a failure is a real addon defect rather than a harness defect, do not fix the addon: record it in your report with the render path.
3. Update `Tools/render/README.md` for any changed variable or behaviour.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**:
- Do not edit `Tools/regression/**` (another PR is rewriting its shell calls) or any addon file. If the fix truly needs a `Tools/regression` file, stop and ask with `orca orchestration ask`.
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.
- You may push your branch and open a **draft** PR against `staging`: title `fix(render): <summary>`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/render/**`, `Tools/tests/test_render*.py` (if such tests exist or you add one), `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups; Windows bar is `gate.sh lint` exit 0 plus your new test; the draft PR's Mac CI proves the rest.

**Evidence of done**: the new auto-size test red on `origin/staging` and green after; `gallery_options` and `gallery_unitframes` `--strict` exit codes before and after with the PNG paths (under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\harness\`), each opened and described; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.
