# Verify: #421 Options layout (slider labels, clipped value, Medallions preview) at 742e556d

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `742e556d32d3b41eb700eefe31d013c3a0ad03de` (draft PR https://github.com/korallis/KstyleUI/pull/421). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\options-overlaps.md`. Author report and crops: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\options\report.txt`.

**Allowed files**: `KstyleUI_Options/**`, `Core/Locales/**` (via strings.py only), `Tools/render/guard.lua`, `Tools/render/scenes/gallery_options*`, `Tools/regression/**` (tests for these defects; `pixel_allow.tsv` only by its generator and only shrinking).

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and four known files are PR 7's). Windows bar: `gate.sh lint` exit 0 plus the new and touched tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering.

**Checks**:
- Each of the four defects is fixed: render `gallery_options` yourself with `--strict` in Frames, Orbs and Medallions at 1920x1080 and 5120x1440, crop the three small windows' sliders, the search window bottom, and the unit-frame preview; open them and describe: no label on text, no clipped value, "Frost Howler" not truncated and not shrunk oddly, portrait ring inside its card.
- The fixes are in the addon layout (not scene tricks that hide a real in-game defect): read `Rows.lua` and `Preview.lua` changes and say whether the game would draw the same thing. Forever rules: `K.Widgets.FontString`, no measurement of restricted regions, API names proven in the source.
- The three new tests fail at base and pass at the SHA (paste both); apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`.
- `pixel_allow.tsv`: regenerate with its generator at the SHA and diff against the committed file (must match); every changed row shrinks or is removed.
- Other settings pages and locales (a long German or French string) still fit: render one page in deDE if the harness supports it.
- CI run 43945710681 green for the SHA; `git diff --stat` within the allowed files; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 742e556d"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
