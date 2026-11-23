# Verify: #442 one premium marketing page (README, CurseForge, Wago) at af3c919b

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `af3c919b3d9c17df2e076723527ac647e3de5045` (draft PR https://github.com/korallis/KstyleUI/pull/442). Base is `f6177f748442522374497ab5f7f8d595fff049af`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\premium-marketing.md` (read the "CurseForge standard" paragraph). Author evidence: README screenshots `%TEMP%\orca-ctx_c9a8d1222d17\readme-1280-s1..s3.png` and `readme-390-s1..s3.png`.

**Gate**: `bash scripts/gate.sh lint` and `gate.sh python` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- CurseForge standard, on `docs/store/description.md` and the CurseForge/Wago blocks: the summary sentence is not the description's first line; no external file-download link (no `releases` link, no icon-pack link) in the CF/Wago blocks; Links and Credits at the bottom; Credits name the OFL fonts and the AI-made art; English; every image truthful (test renders labelled where captions exist; no image implies a feature the addon lacks).
- Truth of every claim: check each benefit and feature line against the code and `docs/feature-map.md` (e.g. "text never drops below a readable size", "profiles you can copy between characters", "every part is its own module, switch one off and it costs nothing", layouts DPS/Tank/Healer, Centred/Spread). Flag any overclaim.
- Rendering: render README with GitHub-flavoured markdown at 1280 and 390 px (headless Chrome) yourself and look at every screen to the end; check image widths are consistent, nothing broken, the 390 layout readable. Confirm the image URLs (`raw.githubusercontent.com/korallis/KstyleUI/main/...`) map to files that exist in the PR (they render once on main).
- Will CurseForge and Wago render the master markdown? Check their markdown support for `<img>`/`![]()` with external https images, `<p align>`/HTML, and tables (from their docs or by checking the current live descriptions on https://addons.wago.io/addons/kstyleui and the CurseForge authors console docs); report anything that would break and how to fix it.
- Images: originality (`Tools/media/marketing.py` uses only the addon's fonts, procedural logo, Tokens colours and existing renders/in-game captures); sizes and weights; text crisp at 1x. Fonts used in images are OFL and credited.
- `Tools/hooks/ci_scope.py` change (outside the task's file list, disclosed): minimal and correct.
- `test_marketing.py` meaningful: mutate the CF block (add a releases link, change a line) and show it fails.
- CI run 44097345409 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified af3c919b"; PASS / ISSUES / BLOCKED; prove every issue; give a short premium-quality critique (what would make it feel more premium, ranked); end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
