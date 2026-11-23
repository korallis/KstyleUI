# Verify: #466 real game scenery behind every published picture at 9253fdde

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `9253fdde15a734330678023e16dfce3d9857733c` (draft PR https://github.com/korallis/KstyleUI/pull/466). Base is `f9747ec6429b927fa230f300ca66afb2291c02d3`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\readme-real-scenery.md`, plus the owner's icon-pack sentence (no URL) and caption rule for repainted icons. Author report with the 48-picture inventory: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_486876acae13\REPORT.md`. Owner rules: no AI-generated scenery in any published picture; README ultrawide heroes stay Spread; the meter bars keep class colours.

**Gate**: `bash scripts/gate.sh lint` and `bash scripts/gate.sh python`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Open every published picture in README.md, `docs/store/description.md`, `docs/media/marketing/` and `docs/store/gallery/` (all 48): each shows real game scenery (a crop of the owner's screenshot, a real capture) or no scenery, never the mockup plate or other generated scenery; captions and alt text say honestly which it is.
- Each plate in `docs/media/plates/` traces in `PROVENANCE.md` to a real screenshot and crop box, contains no old UI, and is not inpainted.
- The new test fails if a pipeline input is the mockup plate (prove it by pointing one at the plate).
- `docs/store/description.md` has the icon-pack sentence with no URL; the CurseForge and Wago blocks match it (`test_marketing.py`); no releases/.zip links.
- Image sizes within the limits; GIFs at most 1 MB; README renders correctly on GitHub (render README to HTML locally and view at 1280 and 390 px).
- CI run 44307581089 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 9253fdde"; PASS / ISSUES / BLOCKED; prove every issue with the file and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
