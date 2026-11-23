# Verify: #461 tooltips follow the mouse out of combat, minimap tooltips beside the map, at 2f4cb4d1

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `2f4cb4d1c7f769101e6bd249a3243a63eb3a143d` (draft PR https://github.com/korallis/KstyleUI/pull/461). Base is `de9665838ee35b384ad4730444b7dd6075eac145`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\tooltip-cursor-out-of-combat.md`, plus the owner's bug: tooltips owned by the minimap or its children must open beside the minimap, never over it, in every anchor mode. Owner rule: every change is toggleable in Options. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_2d05c199063b\report.txt`.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the tooltip tests plus `test-render-scenes-hud.lua`, `test-widgets-lazy.lua`, `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- The new default: cursor out of combat, placed anchor in combat; decided when the tooltip is shown; explicit saved choices ('Anchor', 'Mouse cursor') preserved; fresh profiles get the new default; migration from older saves correct.
- Minimap tooltips: which owners count (Minimap, its children, blips/POIs, addon minimap buttons) and that it is toggleable; the tooltip opens on the side facing screen centre and stays on screen at 1920x1080, 3456x2234 and 5120x1440; nothing else's tooltip changes.
- No taint: GameTooltip owner and anchor changes from insecure code must not taint secure frames (action buttons, unit frames) in combat; check the hook path against the Forever source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`); name the file.
- The hud.lua fixture pin (anchor = fixed) only affects that scene.
- CI run 44286877126 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 2f4cb4d1"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
