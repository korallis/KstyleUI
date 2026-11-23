# Verify: #467 combat readability (H1 plates, H2/H2b, H3, H4, H10, P7, PRD off, bigger plate debuffs) at 3a1754f6

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `3a1754f630032f1015f84e389de3099726688a17` (draft PR https://github.com/korallis/KstyleUI/pull/467). Base is `f9747ec6429b927fa230f300ca66afb2291c02d3`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-Ha.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_d7d5c85f9e95\worker-report.md`. Owner decisions: every change toggleable and ON by default; Blizzard's personal resource display OFF by default, applied on setup and when our option changes only, never fighting a player who turns it on through Blizzard's settings, untouched by Keep my UI; the 18-unit power lane and +22 reserve in Medallions only, Frames/Orbs show power inside the existing bar without moving anything; the Dungeon preset keeps the percent and 12-unit bar and does not shrink debuffs; plate debuffs about 22 units with readable outlined timers and stacks in both presets (size is a slider); the Frames cast bar part of H1 belongs to another PR.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the nameplate, unit-frame, combat-text and layout tests the PR touches plus `test-scalelimit-identity.lua`, `test-layouts-locals.lua`, `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- The personal resource display CVar and API (name the Forever file, `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`); set only out of combat; the four rules above hold (test each).
- Secret safety: interrupt readiness never claimed when secret; no secret health/power compared in Lua; aura data never read back from engine buttons.
- Layout: Layouts.lua reserve offsetY keeps every existing layout's ScaleLimit bit-identical (identity test), the 45 Auto scales unchanged, 7-local margin kept.
- Plates in a pack of 20 at 1920x1080 and 5120x1440 over bright and dark backdrops: debuffs, timers, cast names and percent do not collide (re-render 2 yourself).
- Each new setting defaults on and off restores the base look (spot-check 2).
- CI run 44311516592 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 3a1754f6"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
