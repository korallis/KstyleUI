# Verify: #426 LEE-5826 pixel-grid snapping at 60974c6b

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `60974c6b836090f3678062bb76f87ed47eb2d847` (draft PR https://github.com/korallis/KstyleUI/pull/426). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\lee-5826-pixel-grid.md`. Author report with baseline table and crops: `C:\Users\leeba\.cache\kstyleui-verify\lee-5826\report.md`.

**Allowed files**: `KstyleUI_Skins/Quests/Card.lua`, `KstyleUI_Minimap/Face.lua`, `KstyleUI_DataBars/Strip.lua`, `KstyleUI_DataBars/Bars.lua`, `KstyleUI_Skins/Lumen.lua`, `KstyleUI_QoL/Feed.lua`, `Core/Widgets/Base.lua`, `Tools/regression/pixel_allow.tsv` (generator only), `Tools/regression/**` tests for these owners, `docs/core-visuals.md`.

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and four known files are PR 7's). Windows bar: `gate.sh lint` exit 0 plus the pixel-grid parts and the owners' tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering.

**Checks**:
- Baseline: regenerate `pixel_allow.tsv` with its generator at the SHA and diff with the committed file (must match); every `hud_reference` row is at or below its value before #417 (`git show 0085e0ac:Tools/regression/pixel_allow.tsv`) and no row anywhere rises versus current staging.
- Look: render the warlock in Frames, Orbs and Medallions at 5120x1440, 3456x2234 (game fit) and 1920x1080 with `--strict`; crop the quest card, minimap face, data bars/XP strip, the feed and any `Base.lua` chrome; compare with base at the same size; describe: edges crisper, nothing moved by more than a pixel, nothing clipped or gapped (a snapped size can open a one-pixel seam or cut text).
- `Core/Widgets/Base.lua` is shared by every module: list each behaviour change, run every test that loads it (`gate.sh lua --affected` on the merge with staging), and look at one non-owner surface (a skinned Blizzard window, a tooltip) before and after.
- Forever rules: snapping must not measure restricted regions or compare secret values (in combat, secure frames); show what `Widgets.Point`/`Fill`/`Size` read and when.
- Tests: the owners' new or changed tests fail at base where they claim to; apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`.
- Merges cleanly onto current `origin/staging` (it has #418 and #424); CI run 43951389283 green for the SHA; `git diff --stat` within the allowed files; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 60974c6b"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
