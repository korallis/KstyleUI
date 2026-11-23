# Verify: #430 Medallions target slab fixes at 9d2c1222

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `9d2c1222c8a9605c2131e78ebf6d41dd2d40eeca` (draft PR https://github.com/korallis/KstyleUI/pull/430). Base is `b869840372d95e57c88cbc48f4992b015de2953c`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\acc-1-target-slab.md` (acceptance findings 1, 4, 5). Author evidence: `C:/Users/leeba/.capy/drive/captain-kstyle-project-lead/renders/acceptance-fix-1/REPORT.txt` and `crops/`.

**Gate**: Windows bar: `gate.sh lint` exit 0 plus the touched and new tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering (handoff folder and atlas cache are on this machine).

**Checks**:
- Every creature type the client can return (grep the Forever UI source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone to `C:\Users\leeba\.cache\wow-ui-source` if missing), plus a missing/secret type, with short and long names, at 5120x1440, 3456x2234 (0.8158) and 1920x1080: no ellipsis on the type; the name shrinks in the caps face to a readable floor before truncating; render the hardest cases and open them.
- Localized types: render deDE and frFR (long creature types such as "Mechanisch"/"Mécanique", "Humanoïde") at 3456x2234; nothing overlaps.
- Secret values: names, creature types and widths may be secret; prove no comparison or arithmetic on a secret value and a safe fallback (stubs raise on secret use: run the relevant stub tests).
- Raid marker clear of the debuff row and timers at the three screens, with 0, 1 and a full row of debuffs; the marker still shows for party/raid frames that used the old placement (blast radius).
- The `Preview.lua` and `test-options-preview-content.lua` changes keep #421's Options preview fixes (render `gallery_options --strict` in Medallions).
- Frames and Orbs pixel-identical to base; one row of action buttons unaffected.
- New tests fail at base and pass at the SHA; apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`; CI 43978226314 green for the SHA; merges cleanly onto current `origin/staging`; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 9d2c1222"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
