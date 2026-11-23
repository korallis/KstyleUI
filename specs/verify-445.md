# Verify: #445 /kb hover keybinding and working stance and possess buttons at fed610c6

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `fed610c6af79ac8a458baa06d4a2b44aa5750b3b` (draft PR https://github.com/korallis/KstyleUI/pull/445). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\fb-keybinds.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_575fd6a454bf\report.txt` (red.log and green.log beside it).

**Gate**: `bash scripts/gate.sh` exits 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- Root cause of the stealth click: confirm against the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; local clone `C:\Users\leeba\.cache\wow-ui-source`) that `type=click` to `StanceBar.actionButtons[index]` toggles and cancels stealth the way Blizzard's stance button does, and that it works in combat (secure, no protected writes from insecure code, no taint). Check the claim that Forever has no `POSSESSBUTTONn`/`EXTRAACTIONBUTTON1` binding entries, and that `CLICK PossessButtonn:LeftButton` bindings persist and work.
- Run the red test on the base (it must fail for the stated reason) and green on the head.
- /kb: combat refusal and safe exit on combat start; no `SetBinding`/`SaveBindings`/`SetOverrideBinding*` or protected attribute change in combat; Escape clears; Save writes real game bindings visible in Blizzard's Key Bindings window; Discard restores; mouse buttons, wheel and modifiers; the `/bb` ownership check; no global leaks beyond the `.luacheckrc` line. Look for keyboard capture that could trap the player (keys swallowed after leaving the mode, e.g. `SetPropagateKeyboardInput`), and for hover highlight left behind.
- Look at the render of the /kb mode (scene added by the PR) at 1920x1080 and 5120x1440: KstyleUI style, no truncation (`--strict`).
- Locale: strings synced; translations sensible.
- No change in how anything else looks: run `hud_reference` before/after in Frames, Orbs and Medallions at 1920x1080 and diff (zero differing pixels expected outside the /kb mode).
- CI run 44156545061 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified fed610c6"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
