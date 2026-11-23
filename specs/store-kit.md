# Task: CurseForge and Wago store kit, plus how the release uploads there for WoW Forever

**Goal**: everything needed to create and fill the KstyleUI pages on CurseForge and Wago (Wago Addons) in KstyleUI branding is ready to paste and upload, and the release pipeline is confirmed to upload builds for the Forever client once the owner adds the project IDs and tokens.

**Target**: KstyleUI on the latest `origin/staging`. Release: `.github/workflows/release.yml` (BigWigs packager v2.7.0; uploads to CurseForge when `KstyleUI.toc` has `## X-Curse-Project-ID`, to Wago when it has `## X-Wago-ID`; tokens `CF_API_KEY` and `WAGO_API_TOKEN` in the GitHub `release` environment, both currently unset). The TOC: `## Interface: 16001`, `## AllowLoadGameType: camelot` (the Forever client). Brand: the KstyleUI logo (`Media/Logo/Logo256.png`, chamfered diamond, procedural in `Tools/media/make_media.py`), dark forged UI, gold accents. Marketing pictures: `docs/media/readme/` (hero `hud_medallions_5120.jpg`, styles, crops, GIFs `game_medallions_*.gif`).

**Change**:
1. Research (cite URLs): how CurseForge and Wago list and upload addons for the WoW Forever client: which game/version/flavor each site uses for Forever; how the BigWigs packager maps `## Interface: 16001` / the Forever flavor to CurseForge game versions and Wago `supported_*_patch` fields (read the packager source at the pinned SHA); what other Forever addons that publish to both do (Decursive, Grid2, BigWigs: read their TOC and `.pkgmeta`/workflow). Report exactly what TOC lines, `.pkgmeta` keys or packager arguments KstyleUI needs, and whether anything in `release.yml` must change. Do not change `release.yml`, `.pkgmeta` or the TOC in this task; write the proposed diff in the kit.
2. Store kit under `docs/store/` (docs only, not shipped; `.pkgmeta` already ignores `docs`):
   - `curseforge.md`: project name, summary (CurseForge's character limit), full description in CurseForge's supported markdown, categories to pick, licence choice note (the TOC says All Rights Reserved), source/issues links, and the gallery list with titles and captions.
   - `wago.md`: the same for Wago Addons (its description format and limits, categories/tags).
   - `gallery/`: 6 to 10 images exported from the existing README pictures at each site's recommended gallery size and format (state the sizes from the sites' docs), in story order: Medallions hero, the three styles, ultrawide Spread, setup window, nameplates/meter/quests, a close-up GIF if the site accepts GIFs.
   - `logo/`: the KstyleUI logo rendered by `make_media.py` (add a size parameter or call its logo function; no new art style) at each site's avatar size (CurseForge project avatar, Wago icon), on a transparent or dark background as each site prefers.
   - `CHECKLIST.md`: the owner's steps in order (create the projects, choose game version Forever, categories, paste description, upload gallery and logo, create tokens with the exact scopes, add `CF_API_KEY`/`WAGO_API_TOKEN` to the GitHub `release` environment, send the project IDs to the coordinator), each with the exact page/URL.
   Copy in player language, matching the README's voice (another worker is rewriting the README right now; reuse its pitch where possible but do not edit `README.md`).

**Playbook**: none.

**Constraints**: docs and images only; no changes to the TOC, `.pkgmeta`, `release.yml`, addon code or `README.md`. Never print or store a token. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `docs(store): CurseForge and Wago page kit`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"). Do not merge.

**Files it may edit**: `docs/store/**`, `Tools/media/make_media.py` (only to render the logo at more sizes, with its test updated if one exists).

**Gate**: `bash scripts/gate.sh lint` and `gate.sh python` exit 0.

**Evidence of done**: the research summary with sources and the exact proposed TOC/`.pkgmeta`/workflow diff; every gallery image and logo opened and listed with size; the draft PR's green `checks` run.

**Before worker_done**: Conventional Commits subjects. Report SHA, base SHA, PR URL, run id and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
