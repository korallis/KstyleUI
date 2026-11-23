# Task: re-acceptance of staging for v0.2.3 after the fixes

**Goal**: confirm staging is ready to ship as v0.2.3 now that the acceptance findings are fixed.

**Target**: KstyleUI, the latest `origin/staging` (name the exact SHA you judge). The first acceptance (`C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023\REPORT.md`, staging b8698403) said FIX FIRST: 1 blocker (target slab creature type truncation) and should-fix findings 2 (crest small and dim in the hub), 3 (quest card objective cut beside the RestedXP guide), 4 (long target names dropping to the serif face) and 5 (raid marker over the debuff timers). Fixes merged since: #430 (findings 1, 4, 5), #432 (finding 2), #431 (finding 3), plus #429 and #433 (tests only). Coordinator decisions: finding 4 is met when long names stay in caps where the row has room and fall back beside the longest types; the crest follows KSTY-110 (fills the opening, clipped to it, 256 px art); the quest card uses compact one-quest pages only when the full card does not fit; "one row of action buttons" is a Medallions rule (owner question pending for Frames/Orbs; report but do not block on it).

**Change**: no code changes. Judge and report.
1. For each of findings 1-5, render the same cases the first report used (same scenes, screens 5120x1440, 3456x2234 at the game fit, 1920x1080) and say FIXED / NOT FIXED with a crop.
2. Re-run the composed-HUD comparison: Medallions warlock side by side with the KSTY-110 mock at the three screens (the mock is linked in merged PR #410's Pictures section).
3. Look for regressions the fixes could cause: other HUD styles (Frames and Orbs at the three screens), other windows with headers (#431 changed `Core/Widgets/Base.lua`), the Options gallery, party and nameplates, a vehicle, and locales deDE/frFR on the target slab.
4. Verdict: SHIP or FIX FIRST, with a findings table (severity, screen/style, crop, likely file).

**Playbook**: question / read-only -> cite file:line; change no code.

**Constraints**: Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering (handoff folder and atlas cache are on this machine). Renders go under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-v023-recheck\`. Edit no repository file.

**Files it may edit**: none in the repository.

**Gate**: none (read-only); confirm `bash scripts/gate.sh lint` and `gate.sh lua --affected origin/staging` exit 0 on the judged SHA as a sanity check.

**Evidence of done**: `REPORT.md` in the renders folder with the verdict, the per-finding table with crops, the side-by-side sheets and any new findings.

**Before worker_done**: report the staging SHA judged, the verdict and any blockers.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
