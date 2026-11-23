# Task: one premium marketing page for GitHub, CurseForge and Wago

**Goal**: KstyleUI's GitHub README, CurseForge description and Wago description present the same ultra-polished, premium showcase, with images inside the description, so a player feels "this is a premium UI" within one screen and wants to install it. All three follow CurseForge's standards.

**Target**: KstyleUI, branch from the latest `origin/staging`. Inputs:
- `README.md` (current marketing page; hero is the in-game Medallions shot);
- the store kit `docs/store/` (`curseforge.md`, `wago.md`, `RESEARCH.md`, `CHECKLIST.md`, `gallery/`, `logo/`);
- pictures in `docs/media/readme/` (in-game Medallions `game_medallions_*.jpg/.gif`, test renders of the three HUD styles, ultrawide Spread, setup, nameplates, meter, rails, raid, skins);
- the brand: logo `Media/Logo/Logo256.png` (procedural, `Tools/media/make_media.py` draws it at any size), the addon's own fonts in `Media/Fonts/` (Cinzel, Cinzel Caps, Alegreya Sans, Barlow Semi Condensed; all OFL), dark forged gunmetal with gold accents and class-colour highlights (`Core/Tokens.lua` has the exact colours).

**The CurseForge standard** (moderation policies, checked 2026-11-17, recorded in `docs/store/curseforge.md` "Moderation policy"): a one-sentence summary that is not repeated as the description's first line; a clear description of what the addon does with functional detail; English first; no game name or version in the name; no external download links for files (the optional icon pack is not linked on CurseForge or Wago); links to the source and issue tracker at the bottom; a Credits section (OFL fonts; art original to KstyleUI, the portraits, crests and some textures made with AI image tools; no game art extracted); images must show the addon truthfully (label test renders; no image that misrepresents the addon).

**Change**:
1. Branded image assets, made by a committed script (e.g. `Tools/media/marketing.py`, Pillow only, using the addon's own fonts, logo and colours; original art only, no AI, no game art):
   - a wide banner for the top of every page: the KstyleUI logo and wordmark in Cinzel with the one-line pitch, over a darkened crop of the in-game Medallions shot, with a thin gold rule;
   - section header strips (for example "Three HUDs", "Every screen", "Set up in one window", "The whole interface") in the same style, so each section opens with a branded image;
   - a feature card grid image or set (3 to 6 short benefit cards with an icon-sized crop and two lines of text each);
   - keep files web-light (JPEG or PNG under about 400 KB each; widths 1600 to 2560 for banners) and crisp text.
   Write them under `docs/media/marketing/` and update `Tools/tests/test_render_readme.py` (or add a test) so the new folder and every referenced image are checked.
2. One master description in `docs/store/description.md`: premium copy in player language (short, confident, benefit-first; no internals, PR numbers or test jargon; every claim true to the code, see `docs/feature-map.md`), structured as: banner image, one-sentence hook (not the summary), "why players switch" bullets, then sections each opening with its header strip and one or two showcase images (Medallions first, then Frames and Orbs, ultrawide, setup, nameplates, meter, quests and guide, bags, tooltips, skins), install (CurseForge app, Wago app/WowUp, or by hand), FAQ, then Links (source, issues) and Credits at the bottom. Images are referenced by absolute `https://raw.githubusercontent.com/korallis/KstyleUI/main/...` URLs so the same markdown renders on all three sites.
3. Generate from that master: `README.md` (the same content and order; GitHub-only extras allowed: the download/store badges at the top and, in Install, a short note that the optional icon pack is on the GitHub release page, since GitHub is its own host), `docs/store/curseforge.md` and `docs/store/wago.md` description blocks (exactly the master). Keep `curseforge.md`'s other sections (summary, categories, gallery, moderation policy) and update them if needed. Add a tiny check (in the test above) that the CurseForge and Wago blocks equal the master and contain no `releases` download link.
4. Render the README locally as GitHub would (GitHub-flavoured markdown to HTML, headless Chrome at 1280 and 390 px wide), and screenshot the first three screens at both widths; open them and judge them against a premium standard (alignment, spacing, consistent image widths, no broken images, no wall of text).

**Playbook**: none.

**Constraints**: docs, images and the marketing script only; no addon code; do not change `.github/`, `.pkgmeta` or the TOC. The `docs/` folder is not shipped in the addon zip. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; the handoff folder and atlas cache are on this machine if you need fresh renders (`Tools/render/readme.py`, Spread for 5120x1440). Open a **draft** PR against `staging`: title `docs(marketing): one premium page for GitHub, CurseForge and Wago`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"), and the screenshots' paths. Do not merge.

**Files it may edit**: `README.md`, `docs/store/**`, `docs/media/marketing/**`, `docs/media/readme/**` (only to add or retake pictures), `Tools/media/marketing.py`, `Tools/tests/test_render_readme.py` or a new `Tools/tests/test_marketing.py`.

**Gate**: `bash scripts/gate.sh lint` and `gate.sh python` exit 0.

**Evidence of done**: every new image opened and described in one line with its size; the README screenshots at 1280 and 390 px (first three screens) opened and judged; the master/CF/Wago equality check passing; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
