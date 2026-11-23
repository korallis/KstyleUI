# Verify: #449 filter UNIT_TARGETABLE_CHANGED to boss units at e65ffb00

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `e65ffb00744a4da5744fb86dfaf011d130b46d1a` (draft PR https://github.com/korallis/KstyleUI/pull/449). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\perf-5-targetable-boss.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_f22a1981579e\REPORT.md`.

**Owner constraint**: performance work must not change how anything looks or behaves. A boss frame or target marker that fails to update in any real case is a blocking issue.

**Gate**: `bash scripts/gate.sh lua --affected origin/staging` and `bash scripts/gate.sh lint` exit 0 (CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Test slots are shared and busy: be patient, never stop other processes.

**Checks**:
- Correctness: what did `Frames.MarkTargets()` do for non-boss units before, and does anything now go stale (target, focus, nameplate or arena markers when a non-boss unit becomes untargetable, e.g. a target that phases or goes untargetable mid-fight)? Which unit tokens fire `UNIT_TARGETABLE_CHANGED` in the Forever client (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`), how many boss frames exist (`MAX_BOSS_FRAMES`), and whether the filter covers all of them; name the files. Secret or nil unit arguments.
- Run the new behaviour test red-on-base where it applies and green on the head.
- Pixel proof: re-render 2 of the author's pairs (boss scene Medallions at 5120x1440, `hud_reference` Frames at 1920x1080) base vs head: 0 differing pixels.
- CI run 44175761160 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified e65ffb00"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
