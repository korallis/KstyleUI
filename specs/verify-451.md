# Verify: #451 action-bar cooldown clears at fce0b0e7

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `fce0b0e7bbfc707364889a5c4f622fc9373c56f3` (draft PR https://github.com/korallis/KstyleUI/pull/451). Base is `5ae40d705d0a479fe23239393a681f3af19b9d01`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\perf-3-cooldown-pass.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_8993eeff1acd\REPORT.txt`.

**Owner constraint**: performance work must not change how anything looks. A cooldown sweep, charge ring, GCD sweep or ready flash that fails to clear or to show in any real sequence is a blocking issue.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the ActionBars tests, the new behaviour test and the ActionBars perf entry (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- The Lua-side "cleared" state: every path that starts a cooldown or charge cooldown (both events, action changes, page and bar swaps, stance/possess/vehicle bars, pet bar, empty to filled slot, /kb overlays, profile and style switches, reload, `CooldownFrame` finishing on its own) marks it not clear, so a later real clear is never skipped. Write your own probe that drives random event sequences through base and head and compares each button's cooldown/charge state after every step.
- The claim that Forever only trusts `isOnGCD` inside `SPELL_UPDATE_COOLDOWN`: check the cited Forever source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`).
- Never reads state back from the Cooldown region (AGENTS.md rule).
- Pixel proof: re-render 2 of the author's pairs (combat `hud_reference` Medallions 5120x1440, Frames 1920x1080) base vs head: 0 differing pixels.
- CI run 44208299948 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified fce0b0e7"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
