# Verify: #468 Orbs interiors, Frames centre and Frames cast bars (G5, G6, H1 Frames part) at 03f17fc1

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch the head of draft PR https://github.com/korallis/KstyleUI/pull/468 (SHA starting `03f17fc1`; use `gh pr view 468 --json headRefOid`). Base is `f9747ec6429b927fa230f300ca66afb2291c02d3`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-Gc.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Decisions already made: the Orbs cast-through-pet-name overlap is old UI baked into game_07.png (no geometry change); both Frames cast bars are 14 units tall with the spell name inside at 12 (replaces G6's labels above); every change is toggleable and ON by default; Frames and Orbs keep two action rows (owner rule). The author's PR body lists renders and decisions (G6's 6-unit raise superseded; auras already clear of the map; G8 left to other work).

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the tests the PR touches (including `test-frames-finish.lua`, `test-orbs-finish.lua`) plus `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Regenerated orb textures: made by the committed `Tools/media` script, recorded in `Media/PROVENANCE.md`, power-of-two, in the package; the 'Soft' copies used only when the switch is off.
- Each switch: default on; off restores base pixels exactly (re-render 2 yourself); on matches the plan's change text.
- Frames cast bars: name inside, ink follows what is under the label (merged ink rule), cast and interrupt readable over bright and dark backdrops; target cast label in Orbs has at least 180 units and no ellipsis at 3456x2234 and 5120x1440.
- Medallions unchanged (0 px).
- CI green for the head; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified <head SHA>"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
