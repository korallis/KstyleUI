# Task: make the README a proper marketing page

**Goal**: the GitHub README sells KstyleUI to a WoW Forever player in the first screen and answers "what is it, why is it better, how do I get it" without reading code docs; it is the source copy the CurseForge and Wago pages will reuse.

**Target**: KstyleUI, branch from the latest `origin/staging`. Current `README.md` (Medallions featured as the hero; pictures in `docs/media/readme/`, retaken by `Tools/render/readme.py`; the owner, 2026-11-13: "it's like a marketing page for the addon"; 2026-11-17: the 5120x1440 pictures use the Spread arrangement, Medallions is the featured style, players choose their style in first-run setup). Brand: KstyleUI logo (`Media/Logo/Logo256.png`, the chamfered diamond, drawn by `Tools/media/make_media.py`), dark forged style, gold accents.

**Change**:
- Structure: logo and name, one-line pitch, download badges/links (GitHub release now; CurseForge and Wago links as placeholders `<!-- CF_URL -->`/`<!-- WAGO_URL -->` the coordinator fills once the projects exist), the Medallions hero, then short scannable sections with one picture each: three HUD styles (Medallions first), every screen including ultrawide, setup in one window, the rest of the UI (nameplates, meter, quests and guide, bags, tooltips, skins), performance and pixel-perfect, install, FAQ (supported client: WoW Forever; RestedXP support; how to switch style; how to report a bug), credits and licence.
- Copy: player language, short sentences, benefits first; no internals, PR numbers or test jargon; keep every claim true to the current code (check features against `docs/feature-map.md`). Keep "test render" captions honest but short.
- Use the existing pictures (and the animated GIFs `game_medallions_*.gif` where they help); add a centred logo at the top using `Media/Logo/Logo256.png` (or a larger render of the same logo from `make_media.py` saved under `docs/media/readme/` if it looks soft). No new HUD renders.
- Keep anchors consistent and every image path valid.

**Playbook**: none.

**Constraints**: docs only. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Run `Tools/tests/test_render_readme.py` and any README test. Open a **draft** PR against `staging`: title `docs(readme): marketing page`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"). Do not merge.

**Files it may edit**: `README.md`, `docs/media/readme/logo*.png` (new logo render only).

**Gate**: `bash scripts/gate.sh lint` and `gate.sh python` exit 0.

**Evidence of done**: the new outline; a check that every image path and anchor resolves; a rendered preview of the README (GitHub-flavoured markdown rendered to HTML locally, screenshot the top two screens with headless Chrome) opened and described; the draft PR's green `checks` run.

**Before worker_done**: Conventional Commits subjects. Report SHA, base SHA, PR URL, run id and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
