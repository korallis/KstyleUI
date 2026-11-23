# Verify: #432 crest clipped to the hub opening, at b98f4327

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `b98f43276ea9c1e5ba1961ed486903a4e4c52e58` (draft PR https://github.com/korallis/KstyleUI/pull/432). Edit nothing, push nothing, comment nothing.

**Context**: acceptance finding 2 (crest small and dim in the hub). First verify (`C:\Users\leeba\.cache\kstyleui-verify\v432\REPORT.md`) found the enlarged crest spilled outside the ring for 10 of 52 crests, sheen/flash landed on the ring, and the crest was upscaled past its bake at 4K. Coordinator decisions: follow KSTY-110 (the crest fills the ring's opening and is clipped to it by a circular mask; crest, bloom, sheen and flash all clipped/sized to the opening); keep the original 256 px crest art (no re-bake; the release zip stays about 28.8 MB) and never draw a crest larger than its 256 px bake. The PR has seven changed files and no asset changes. Author evidence: `C:\Users\leeba\.cache\kstyleui-verify\v432-256\REPORT.md`. Spec: `C:\Projects\KstyleUI\specs\acc-2-hub-crest.md`.

**Gate**: Windows: `gate.sh lint` exit 0, `gate.sh lua --affected origin/staging` exit 0 natively, and `gate.sh python`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering (handoff folder and atlas cache are on this machine).

**Checks**:
- The mask: prove the API used (MaskTexture / `CreateMaskTexture` / `AddMaskTexture` or whatever the code uses) exists on Forever (grep the `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone to `C:\Users\leeba\.cache\wow-ui-source` if missing) and that the mask texture file is a valid client mask (format, power of two, registered); the stub's mask support matches the client (does the render harness actually apply the mask, or would a broken mask still look clipped in renders? check).
- Render the hub for the warlock, every tauren and skyborne crest, and three others at 5120x1440, 3456x2234 (0.8158), 1920x1080 and 3840x2160 with `--strict`; open them: nothing past the ring's inner edge in any state (rest, combat, low health, level-up burst, procs, vehicle); crest crisp (never above 256 px); brightness matches KSTY-110.
- One row of action buttons and action buttons above the hub still hold; ring size unchanged; Frames and Orbs pixel-identical to staging.
- The all-52 alpha clip test is meaningful (mutate the mask radius or remove the mask and show it fails).
- CI 44003690947 green for the SHA; merges cleanly onto current `origin/staging`; `git diff --stat` shows no asset changes; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified b98f4327"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
