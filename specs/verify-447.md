# Verify: #447 group-frame prediction ranges only when the max can change at 2691ed80

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `2691ed80b9c25af50458b1c07b6109040f2efc62` (draft PR https://github.com/korallis/KstyleUI/pull/447). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\perf-4-prediction-ranges.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_c53e2970c88f\report.md`.

**Owner constraint**: performance work must not change how anything looks, ever. A single differing pixel or a bar that shows a wrong amount in any sequence is a blocking issue.

**Gate**: `bash scripts/gate.sh lua --affected origin/staging` and `bash scripts/gate.sh lint` exit 0 (CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. The machine's test slots are shared and busy: be patient, never stop other processes.

**Checks**:
- Correctness: hunt for any path where a unit's max health changes, or a frame starts showing a different unit, without the range being reset: `UNIT_MAXHEALTH` order relative to `UNIT_HEALTH`, roster changes and frame reuse, pets, vehicles (unit swaps to vehicle), `UNIT_CONNECTION`, phasing, death and resurrection, the Options preview and test mode, a reload in a group. Confirm against the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`) and name the files. Secret values: nothing compares the max in Lua.
- Write your own probe (outside the repo) that drives randomised health/max-health/unit-change sequences through base and head and compares every prediction bar's value and range after each step.
- Pixel proof: re-render 3 of the author's pairs yourself (raid in Medallions at 5120x1440, party in Frames at 1920x1080, one at 3456x2234) and diff base vs head: 0 pixels.
- Measurement: re-run the raid-40 benchmark under PUC lua5.1 (base vs head, interleaved) and confirm the SetMinMaxValues/s drop.
- CI run 44174620718 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 2691ed80"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
