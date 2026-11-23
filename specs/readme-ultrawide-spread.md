# Task: README ultrawide HUD pictures use the full width (Spread)

**Goal**: the README's 5120x1440 HUD pictures show the ultrawide used edge to edge, as the owner wants, instead of the Centred 21:9 band.

**Target**: KstyleUI, branch from the latest `origin/staging`. `Tools/render/readme.py` renders the three hero pictures `hud_orbs_5120`, `hud_frames_5120` and `hud_medallions_5120` (`RENDERS[_key + "_5120"]`, env `ULTRAWIDE` + `style_env`) with the default arrangement, which is Centred. The owner, 2026-11-17: "the ultra wide screenshot should be with the ultra wide set to the full thing instead of centered".

**Change**:
- In `readme.py`, render the three `*_5120` HUD pictures with `RENDER_ARRANGEMENT=spread`. Leave the "Every screen, ultrawide included" pair (`ultrawide_centred`, `ultrawide_spread`) as it is, since it deliberately compares the two arrangements, and leave every non-5120 picture unchanged.
- Retake those three pictures with `python Tools/render/readme.py` (the handoff folder and atlas cache are on this machine; use the Chrome wrapper approach from the last release-prep run if Windows Chrome needs it, outside the repo). Open each and confirm the HUD, rails and cards reach the screen edges and everything renders strict-clean.
- Update the README alt text and captions for those three pictures (for example `hud_frames_5120`'s alt text says "centred in the middle of the ultrawide") to describe the Spread layout.

**Playbook**: none.

**Constraints**: docs and the readme renderer only; no addon code. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. Open a **draft** PR against `staging`: title `docs(readme): show the ultrawide HUD pictures in the Spread arrangement`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"), and the changed pictures. Do not merge.

**Files it may edit**: `Tools/render/readme.py`, `README.md`, the three `docs/media/readme/hud_*_5120.jpg` pictures, `Tools/tests/test_render_readme*.py` if a test pins the arrangement.

**Gate**: `bash scripts/gate.sh` (lint and python exit 0).

**Evidence of done**: the three new pictures opened and described (one line each), the `readme.py` exit code, any README test passing, and the draft PR's green `checks` run.

**Before worker_done**: Conventional Commits subjects. Report SHA, base SHA, PR URL, run id and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
