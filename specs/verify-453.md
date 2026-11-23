# Verify: #453 Medallions debuff fan above the crest at ff8ee34b

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `ff8ee34b7c37e82551e22f9cae307a53592a16f5` (draft PR https://github.com/korallis/KstyleUI/pull/453). Base is `debefa8c949354633f8e7411687c818088e1d7c5`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\medallions-crest-debuffs.md` (owner update: every debuff the player applied, `HARMFUL|PLAYER`). Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_2bfd9da3d486\final-report.md` (renders and evidence beside it).

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the unitframes, auras, actionbars and layout tests plus the new fan tests, `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Secret safety in combat: the fan relies on Blizzard's aura containers (seven clipping windows over an identically sorted native prefix). Confirm against the Forever source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`) that nothing reads secret aura data, live button counts or positions, no protected frame is touched in combat, and `DisableUntrustedLayoutScriptsTemplate` / `SetClipsChildren` / `AddPandemicRegion` are used as Blizzard intends; name the files.
- Behaviour: your DoTs and other `HARMFUL|PLAYER` auras (pet and vehicle included) appear in the fan and not on the target medallion; other players' debuffs stay on the medallion; target change, death, out of range, more than seven debuffs, reload in combat, the option off (everything back as before), Layout Mode, Frames and Orbs unchanged (0 px).
- Duplicates: the medallion's filter excludes exactly the fan's set in every state, including when the fan is off or hidden.
- Look: open the fan renders (1, 3, 7 debuffs at 1920x1080 and 5120x1440, plus dark and bright backdrops) and judge spacing, overlap with the cast bars and crest, timer legibility, and consistency with KstyleUI's icon style.
- CI run 44225066334 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified ff8ee34b"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
