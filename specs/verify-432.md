# Verify: #432 crest fills the Medallions hub at 8ec08c40

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `8ec08c40585255e1d3703c115b90e0196ac9db6a` (draft PR https://github.com/korallis/KstyleUI/pull/432). Base is `9080721b0e1d7564d81655619b5c728d5026d295`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\acc-2-hub-crest.md` (acceptance finding 2). Author evidence: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\acceptance-fix-2\REPORT.md` and `sheets/hub-*.png`.

**Gate**: Windows bar: `gate.sh lint` exit 0 plus the touched tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering (handoff folder and atlas cache are on this machine).

**Checks**:
- Render the hub for the undead warlock and at least four other race/class crests (include a wide crest and a tall one) in Medallions at 5120x1440, 3456x2234 (0.8158) and 1920x1080 with `--strict`; open them: the crest fills the ring's opening without touching or overlapping the ring, the level badge and the cast bars above stay clear, the crest is crisp (no upscaling blur at 5120x1440), and brightness at rest and in combat matches the KSTY-110 mock.
- Every state that changes the crest (rest, combat, low health, level-up burst, proc glows, vehicle) still lines up with the larger crest: nothing sized for the old 108 now misaligns (grep every use of the crest/socket sizes).
- One row of action buttons and action buttons above the hub still hold (`test-actionbars-medallions-slab`, `test-layout-medallions-hub`); the hub ring size is unchanged.
- Frames and Orbs pixel-identical to base.
- The new test fails at base and passes at the SHA; CI 43979993357 green for the SHA; merges cleanly onto current `origin/staging`; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 8ec08c40"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
