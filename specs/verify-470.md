# Verify: #470 a quiet slab (D1-D4, D7), G2 and the hub alpha fix at a744d634

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `a744d63405a2163a9803ac72412eb564ab011c3d` (draft PR https://github.com/korallis/KstyleUI/pull/470). Base is `c5e1e9b833ff5bb116c7e177dcc1d0ae64316766`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-D.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_5ab8b643dfd3\completion-report.txt`. Owner rules: every change toggleable and ON by default; D1 (empty sockets at 0.4) and D4 (crest at 123 units) approved; the one-row rule is Medallions only; the two cooldown events stay separate (#451).

**Local checks**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the action-bar, cooldown, aura, group and widget tests the PR touches plus `test-comments.lua` and `test-syntax.lua` (no full local suite: CI ran it). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders at a time.

**Checks**:
- Hub alpha fix: each region's alpha applied once (no GetAlpha copied into vertex alpha); particles and combat sweeps now show in the truthful harness; nothing else in the hub brighter than designed.
- D1: empty sockets dim only when no drag, Layout Mode or bind mode; restore immediately on drag, /kb and Layout Mode; protected button geometry never changed in combat.
- D2/D3: SetDrawEdge and SetEdgeScale exist in Forever (name the file, `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`); the countdown never parsed when secret; keybind and countdown never overlap at 33.5 and 26.6-unit sockets.
- D4: crest seated at 123 units with bloom and pulse scaled together; the crest debuff fan (#453) space above the crest untouched.
- D7/G2: icon frames and lanes per plan.
- Each of the ten settings defaults on; off restores base (spot-check 3 zero-diffs yourself).
- CI run 44326109889 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified a744d634"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.
