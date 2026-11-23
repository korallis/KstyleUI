# Arena candidate: KstyleUI 10/10 scorecard, plan and before/after mockup page

**Goal**: the owner asked for "a full visual audit scoring our UI out of 10 for performance, visual effects, aesthetics and what a player needs, then the things you would improve to get the score to 10/10. Finesse, elegance and polish are the top priorities. An HTML mockup showcasing the differences you'd like to apply." Twelve independent audits are done (each lens by Claude, Codex and Grok). You are one of three candidates building the same final artifact from them; the best one becomes the base and the others are grafted in, so build the complete thing, not a sketch.

**Inputs** (read all twelve end to end before writing):
- `C:\Users\leeba\.cache\kstyleui-audit\aesthetics.md` (Claude, 6.4), `aesthetics-codex.md` (7.4), `aesthetics-grok.md` (6.8)
- `effects.md` (Claude, 5.5), `effects-codex.md` (7.3), `effects-grok.md` (6.5)
- `performance.md` (Claude, 5.5 before / 6.5 after the in-flight fixes), `performance-codex.md` (6.4 / 7.8), `performance-grok.md` (5 / 6.5)
- `player.md` (Grok, 6.5), `player-claude.md` (6.5), `player-codex.md` (7.3)
- Their renders and crops under `C:\Users\leeba\.cache\kstyleui-audit\renders*\`, references under `refs*\`, the owner's real game screenshots `C:\Users\leeba\.cache\kstyleui-backdrops\game_01..09.png` (5120x1440; game_03-08 are older builds), and the in-game captures in the repo's `docs/media/readme/game_*`.
- The repo (your worktree): `docs/superpowers/specs/2026-11-07-kstyleui-design.md`, `Core/Tokens.lua`, `docs/feature-map.md`, `Tools/render/README.md`.

**Owner rulings the plan must respect** (flag, never silently override): the one-row action-bar rule applies to Medallions only (Frames and Orbs keep two rows); the player picks the HUD style in setup (Medallions is not forced as default); README ultrawide heroes use Spread; performance work must be pixel-identical (look changes are allowed only as explicit design items needing sign-off). Already in flight, do not re-propose as new: PR #445 /kb (merged), #446 font height, #447 group prediction ranges, #448 scale search, #449 boss targetable filter, lazy widget regions (perf fix 2), action-bar cooldown clears (perf fix 3; the client forbids merging the two cooldown events), the RestedXP arrow contrast fix, and a Caith-style fan of the player's debuffs above the Medallions crest.

**Artifact** (all in `C:\Users\leeba\.cache\kstyleui-audit\arena\candidate-<you>\`, where `<you>` is claude, codex or grok as named in your task title):
1. `scorecard.md`: per lens, the three model scores side by side, a consensus score and one line on why the models differ; per area within each lens the same. An overall score today and the projected score after the plan.
2. `plan.md`: the ranked plan to 10/10. Merge duplicate findings across the twelve reports; give each item: what is wrong (evidence: picture path + crop, or file:line), the exact change (units, Tokens names or hex, ms and curves), which reports found it (agreement = confidence), score impact per lens, effort S/M/L, risk, and whether it changes the look (needs owner sign-off) or is pixel-identical. Order by impact on finesse, elegance and polish first, then player value, then performance. Group into shippable batches (each a sensible PR).
3. `index.html` plus `img/`: one polished, self-contained page the owner opens in a browser:
   - a hero with the overall score today and after;
   - the scorecard (four lenses x three models);
   - for each of the top 12-15 improvements, a **before / after** pair at the same crop and scale: "before" is a real render or game capture, "after" shows the proposed change. Build the "after" for the visual items by actually applying the change to a scratch copy of the addon in your worktree (never commit or push) and rendering it with `Tools/render/shoot.sh` (use `--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_NN.png`, the `/c/...` form; the owner wants real game backgrounds), or, where that is impractical, a faithful composite or HTML/CSS/SVG mock clearly labelled "mock". A slider or toggle per pair is welcome. Label every image honestly (render, in-game capture, mock);
   - the plan's batches with effort and sign-off flags.
   Page rules: title of two to four words; colours as CSS custom properties on `:root` with a dark variant under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])` and repeated under `:root[data-theme="dark"]`; `body` has an explicit background; works at phone width with a 16 px side gutter and no horizontal scroll; no external scripts or CDNs (fonts from Google Fonts allowed, or the addon's own OFL fonts copied into `img/` with their licence); images as JPEG or WebP, each at most 400 KB, total folder at most 40 MB. It should itself feel premium, in KstyleUI's dark forged-chrome style.
4. `rationale.md`: the alternatives you considered for scoring, ordering and presentation and what you rejected.

**Rubric the picker will use**: (1) every score and claim traces to a report or measurement; (2) the plan raises finesse, elegance and polish most per unit of effort; (3) changes are precise enough to implement without guessing; (4) the before/after pairs are honest, same-crop, and actually show the difference; (5) feasible in this codebase and the Forever client, and respects the owner rulings; (6) the page's own polish and readability.

**Constraints**: change and commit nothing in the repository; scratch patches live only in your worktree and are discarded. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. The machine is shared: at most 2 renders at a time; never stop processes you did not start. Read-only for the repository; no PR.

**Files it may edit**: none in the repository; only `C:\Users\leeba\.cache\kstyleui-audit\arena\candidate-<you>\**` and scratch under `%TEMP%`.

**Gate**: none (read-only).

**Evidence of done**: open `index.html` in headless Chrome at 1440 px and 390 px wide, screenshot the full page at both widths, look at every screen to the end, and fix anything broken; list the screenshot paths. Report the total folder size.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the folder path, the overall score today and after, and your top five plan items.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
