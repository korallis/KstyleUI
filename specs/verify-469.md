# Verify: #469 one type voice (C1-C5) at 34b55b12

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `34b55b12211c2133ffa3f49d71a4693bd18d27c8` (draft PR https://github.com/korallis/KstyleUI/pull/469). Base is `92135ee2369fa44474f2d8cf739b8c601d4da5fc`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-C.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_38396ab32a07\report.md`. Decisions already made: no baked Barlow variant (tracking unchanged); Lumen.SectionCap and the RestedXP captions follow C5; increased tooltip pixel allowances carry LEE-5882; every change toggleable and ON by default; the text-floor setting must feed the saved scale cache key if it can change a ScaleLimit result.

**Local checks**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the tests the PR touches plus `test-scalelimit-identity.lua`, `test-comments.lua` and `test-syntax.lua` (no full local suite: CI ran it). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders at a time.

**Checks**:
- C1: at 3456x2234 the Medallions target name keeps its face and case; the text floor comes from the effective UI scale; text sizes unchanged at 1920x1080 and 5120x1440 unless the plan says so; the cache key includes the floor (toggle it and confirm no stale scale).
- C2-C5: match the plan; translations fit (deDE, frFR, zhCN) with no truncation (`--strict`).
- pixel_allow.tsv: only C-affected entries changed, decreases lowered, increases labelled LEE-5882 and small; nothing else loosened.
- No secret geometry reads (the author fixed one in the cap rule: confirm none remain).
- Each setting defaults on and off restores base (spot-check 2 zero-diffs yourself).
- CI run 44322508970 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 34b55b12"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.
